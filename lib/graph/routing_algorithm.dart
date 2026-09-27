import '../models/station.dart';
import '../models/graph_edge.dart';
import '../models/route_result.dart';
import 'transit_graph.dart';

enum RoutingPreference {
  fastestTime,
  leastTransfers,
}

class RoutingAlgorithm {
  final TransitGraph graph;

  RoutingAlgorithm(this.graph);

  /// Computes the optimal offline path using the A* algorithm
  RouteResult? findRoute({
    required String originStationId,
    required String destinationStationId,
    RoutingPreference preference = RoutingPreference.fastestTime,
    int transferPenaltySeconds = 240, // 4-minute penalty per line change
  }) {
    final start = graph.getStation(originStationId);
    final target = graph.getStation(destinationStationId);

    if (start == null || target == null) return null;
    if (start.id == target.id) {
      return RouteResult(
        origin: start,
        destination: target,
        fullPath: [start],
        segments: [],
        totalDurationSeconds: 0,
        interchangeCount: 0,
        deadzoneStations: start.isDeadzone ? [start] : [],
      );
    }

    // Priority queue tracking (cost, stationId, currentLineId)
    final openSet = _PriorityQueue<_SearchNode>((a, b) => a.fScore.compareTo(b.fScore));
    
    // gScore: cheapest cost to reach a station state
    // Key: stationId:lastLineId (since line changes carry transfer penalties)
    final gScore = <String, double>{};
    final cameFrom = <String, _PreviousStep>{};

    final startState = _stateKey(start.id, null);
    gScore[startState] = 0.0;

    final initialH = _heuristic(start, target);
    openSet.add(_SearchNode(
      stationId: start.id,
      currentLineId: null,
      gScore: 0.0,
      fScore: initialH,
    ));

    String? bestEndStateKey;
    double bestEndCost = double.infinity;

    while (openSet.isNotEmpty) {
      final current = openSet.removeFirst();
      final currState = _stateKey(current.stationId, current.currentLineId);

      // Early exit if destination reached
      if (current.stationId == target.id) {
        if (current.gScore < bestEndCost) {
          bestEndCost = current.gScore;
          bestEndStateKey = currState;
          break; // First arrival at target with admissible heuristic is optimal
        }
      }

      if (current.gScore > (gScore[currState] ?? double.infinity)) {
        continue; // Stale node in priority queue
      }

      final edges = graph.getOutgoingEdges(current.stationId);
      for (final edge in edges) {
        final neighbor = graph.getStation(edge.toStationId);
        if (neighbor == null) continue;

        // Calculate edge cost with transfer penalty
        double addedCost = edge.travelTimeSeconds.toDouble();

        // If changing lines or taking an interchange walk
        final isLineSwitch = current.currentLineId != null &&
            edge.lineId != null &&
            current.currentLineId != edge.lineId;

        if (isLineSwitch || edge.type == EdgeType.transferWalk) {
          if (preference == RoutingPreference.leastTransfers) {
            addedCost += transferPenaltySeconds * 2.0; // Higher penalty to avoid changing
          } else {
            addedCost += transferPenaltySeconds;
          }
        }

        final tentativeG = current.gScore + addedCost;
        final nextLineId = edge.lineId ?? current.currentLineId;
        final nextState = _stateKey(neighbor.id, nextLineId);

        if (tentativeG < (gScore[nextState] ?? double.infinity)) {
          gScore[nextState] = tentativeG;
          cameFrom[nextState] = _PreviousStep(
            prevStateKey: currState,
            edge: edge,
            fromStation: graph.getStation(current.stationId)!,
            toStation: neighbor,
          );

          final h = _heuristic(neighbor, target);
          openSet.add(_SearchNode(
            stationId: neighbor.id,
            currentLineId: nextLineId,
            gScore: tentativeG,
            fScore: tentativeG + h,
          ));
        }
      }
    }

    if (bestEndStateKey == null) {
      return null; // No route possible
    }

    return _reconstructPath(start, target, cameFrom, bestEndStateKey);
  }

  /// Admissible A* Heuristic: Haversine distance divided by max metro speed (80 km/h = 22.2 m/s)
  double _heuristic(Station current, Station target) {
    const double maxTransitSpeedMps = 22.2;
    final dist = current.distanceTo(target);
    return dist / maxTransitSpeedMps;
  }

  String _stateKey(String stationId, String? lineId) => '$stationId:${lineId ?? "none"}';

  RouteResult _reconstructPath(
    Station origin,
    Station destination,
    Map<String, _PreviousStep> cameFrom,
    String endStateKey,
  ) {
    final edgesTraversed = <GraphEdge>[];
    final stationsTraversed = <Station>[destination];

    String? currentKey = endStateKey;
    while (cameFrom.containsKey(currentKey)) {
      final step = cameFrom[currentKey]!;
      edgesTraversed.insert(0, step.edge);
      stationsTraversed.insert(0, step.fromStation);
      currentKey = step.prevStateKey;
    }

    // Group into high-level route segments (e.g. Yellow Line ride, then transfer, then Blue Line)
    final segments = <RouteSegment>[];
    int totalTimeSeconds = 0;
    int interchanges = 0;
    final deadzones = <Station>[];

    for (final s in stationsTraversed) {
      if (s.isDeadzone && !deadzones.contains(s)) {
        deadzones.add(s);
      }
    }

    if (edgesTraversed.isNotEmpty) {
      String? currentLineId = edgesTraversed.first.lineId;
      EdgeType currentType = edgesTraversed.first.type;
      var segmentStartStation = stationsTraversed.first;
      var segmentStations = <Station>[segmentStartStation];
      int segmentDuration = 0;
      String? segmentWalkingVector = edgesTraversed.first.walkingVector;

      for (int i = 0; i < edgesTraversed.length; i++) {
        final edge = edgesTraversed[i];
        final nextStation = stationsTraversed[i + 1];
        totalTimeSeconds += edge.travelTimeSeconds;

        final isDifferentMode = edge.type != currentType ||
            (edge.lineId != currentLineId && edge.type == EdgeType.rail);

        if (isDifferentMode && segmentStations.length > 1) {
          // Flush existing segment
          segments.add(RouteSegment(
            line: currentLineId != null ? graph.getLine(currentLineId) : null,
            fromStation: segmentStartStation,
            toStation: segmentStations.last,
            stations: List.unmodifiable(segmentStations),
            durationSeconds: segmentDuration,
            type: currentType,
            walkingVector: segmentWalkingVector,
          ));

          if (currentType == EdgeType.transferWalk ||
              currentType == EdgeType.pedestrianLink ||
              (currentLineId != null && edge.lineId != null && currentLineId != edge.lineId)) {
            interchanges++;
          }

          // Start new segment
          currentLineId = edge.lineId;
          currentType = edge.type;
          segmentStartStation = segmentStations.last;
          segmentStations = [segmentStartStation, nextStation];
          segmentDuration = edge.travelTimeSeconds;
          segmentWalkingVector = edge.walkingVector;
        } else {
          segmentStations.add(nextStation);
          segmentDuration += edge.travelTimeSeconds;
          if (edge.walkingVector != null) segmentWalkingVector = edge.walkingVector;
        }
      }

      // Flush final segment
      segments.add(RouteSegment(
        line: currentLineId != null ? graph.getLine(currentLineId) : null,
        fromStation: segmentStartStation,
        toStation: segmentStations.last,
        stations: List.unmodifiable(segmentStations),
        durationSeconds: segmentDuration,
        type: currentType,
        walkingVector: segmentWalkingVector,
      ));

      if (currentType == EdgeType.transferWalk || currentType == EdgeType.pedestrianLink) {
        interchanges++;
      }
    }

    return RouteResult(
      origin: origin,
      destination: destination,
      fullPath: stationsTraversed,
      segments: segments,
      totalDurationSeconds: totalTimeSeconds,
      interchangeCount: interchanges,
      deadzoneStations: deadzones,
    );
  }
}

class _PreviousStep {
  final String prevStateKey;
  final GraphEdge edge;
  final Station fromStation;
  final Station toStation;

  _PreviousStep({
    required this.prevStateKey,
    required this.edge,
    required this.fromStation,
    required this.toStation,
  });
}

class _SearchNode {
  final String stationId;
  final String? currentLineId;
  final double gScore;
  final double fScore;

  _SearchNode({
    required this.stationId,
    required this.currentLineId,
    required this.gScore,
    required this.fScore,
  });
}

/// Simple Binary Min-Heap for A* Priority Queue
class _PriorityQueue<T> {
  final List<T> _heap = [];
  final int Function(T a, T b) _comparator;

  _PriorityQueue(this._comparator);

  bool get isNotEmpty => _heap.isNotEmpty;

  void add(T element) {
    _heap.add(element);
    _siftUp(_heap.length - 1);
  }

  T removeFirst() {
    if (_heap.isEmpty) throw StateError('Queue is empty');
    final result = _heap.first;
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      _siftDown(0);
    }
    return result;
  }

  void _siftUp(int index) {
    while (index > 0) {
      final parentIndex = (index - 1) ~/ 2;
      if (_comparator(_heap[index], _heap[parentIndex]) < 0) {
        final tmp = _heap[index];
        _heap[index] = _heap[parentIndex];
        _heap[parentIndex] = tmp;
        index = parentIndex;
      } else {
        break;
      }
    }
  }

  void _siftDown(int index) {
    final length = _heap.length;
    while (true) {
      int left = 2 * index + 1;
      int right = 2 * index + 2;
      int smallest = index;

      if (left < length && _comparator(_heap[left], _heap[smallest]) < 0) {
        smallest = left;
      }
      if (right < length && _comparator(_heap[right], _heap[smallest]) < 0) {
        smallest = right;
      }
      if (smallest != index) {
        final tmp = _heap[index];
        _heap[index] = _heap[smallest];
        _heap[smallest] = tmp;
        index = smallest;
      } else {
        break;
      }
    }
  }
}
