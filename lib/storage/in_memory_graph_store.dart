import '../graph/transit_graph.dart';
import '../models/congestion.dart';
import 'graph_store.dart';

class InMemoryGraphStore implements GraphStore {
  TransitGraph _storedGraph = TransitGraph();
  int _syncVersion = 0;

  final List<CongestionRecord> _outbox = [];
  final Map<String, StationCongestionSnapshot> _congestionCache = {};

  @override
  void saveGraph(TransitGraph graph) {
    _storedGraph = TransitGraph();
    for (final l in graph.lines.values) {
      _storedGraph.addLine(l);
    }
    for (final s in graph.stations.values) {
      _storedGraph.addStation(s);
    }
    for (final edges in graph.adjacency.values) {
      for (final e in edges) {
        _storedGraph.addEdge(e);
      }
    }
  }

  @override
  TransitGraph loadGraph({String? city}) {
    if (city == null) return _storedGraph;
    final filtered = TransitGraph();
    for (final l in _storedGraph.lines.values.where((l) => l.city.toLowerCase() == city.toLowerCase())) {
      filtered.addLine(l);
    }
    for (final s in _storedGraph.stations.values.where((s) => s.city.toLowerCase() == city.toLowerCase())) {
      filtered.addStation(s);
    }
    for (final edges in _storedGraph.adjacency.values) {
      for (final e in edges) {
        if (filtered.stations.containsKey(e.fromStationId) &&
            filtered.stations.containsKey(e.toStationId)) {
          filtered.addEdge(e);
        }
      }
    }
    return filtered;
  }

  @override
  int getSyncVersion() => _syncVersion;

  @override
  void setSyncVersion(int version) {
    _syncVersion = version;
  }

  @override
  void queueOutboxCongestion(CongestionRecord record) {
    _outbox.add(record);
  }

  @override
  List<CongestionRecord> getPendingOutboxCongestion() {
    return List.unmodifiable(_outbox);
  }

  @override
  void clearOutboxCongestion(List<String> ids) {
    final idSet = ids.toSet();
    _outbox.removeWhere((item) => idSet.contains(item.id));
  }

  @override
  void updateStationCongestion(String stationId, int score, DateTime timestamp) {
    _congestionCache[stationId] = StationCongestionSnapshot(
      stationId: stationId,
      score: score,
      updatedAt: timestamp,
    );
  }

  @override
  StationCongestionSnapshot? getStationCongestion(
    String stationId, {
    Duration timeout = const Duration(minutes: 45),
  }) {
    final item = _congestionCache[stationId];
    if (item == null) return null;
    if (item.isStale(timeout: timeout)) return null;
    return item;
  }

  @override
  Map<String, StationCongestionSnapshot> getAllStationCongestion({
    Duration timeout = const Duration(minutes: 45),
  }) {
    final valid = <String, StationCongestionSnapshot>{};
    for (final entry in _congestionCache.entries) {
      if (!entry.value.isStale(timeout: timeout)) {
        valid[entry.key] = entry.value;
      }
    }
    return valid;
  }

  @override
  void close() {
    _storedGraph.clear();
    _outbox.clear();
    _congestionCache.clear();
  }
}
