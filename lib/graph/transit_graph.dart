import 'dart:math' as math;
import '../models/station.dart';
import '../models/transit_line.dart';
import '../models/graph_edge.dart';

class TransitGraph {
  final Map<String, Station> _stations = {};
  final Map<String, TransitLine> _lines = {};
  final Map<String, List<GraphEdge>> _adjacency = {};

  Map<String, Station> get stations => Map.unmodifiable(_stations);
  Map<String, TransitLine> get lines => Map.unmodifiable(_lines);
  Map<String, List<GraphEdge>> get adjacency => Map.unmodifiable(_adjacency);

  int get stationCount => _stations.length;
  int get lineCount => _lines.length;
  int get edgeCount => _adjacency.values.fold(0, (sum, list) => sum + list.length);

  void addStation(Station station) {
    _stations[station.id] = station;
    _adjacency.putIfAbsent(station.id, () => []);
  }

  void addLine(TransitLine line) {
    _lines[line.id] = line;
  }

  void addEdge(GraphEdge edge) {
    _adjacency.putIfAbsent(edge.fromStationId, () => []).add(edge);
  }

  void addBidirectionalRailEdge({
    required Station from,
    required Station to,
    required String lineId,
    required int travelTimeSeconds,
    double? distanceMeters,
  }) {
    final dist = distanceMeters ?? from.distanceTo(to);
    addEdge(GraphEdge(
      fromStationId: from.id,
      toStationId: to.id,
      lineId: lineId,
      travelTimeSeconds: travelTimeSeconds,
      distanceMeters: dist,
      type: EdgeType.rail,
    ));
    addEdge(GraphEdge(
      fromStationId: to.id,
      toStationId: from.id,
      lineId: lineId,
      travelTimeSeconds: travelTimeSeconds,
      distanceMeters: dist,
      type: EdgeType.rail,
    ));
  }

  void addInterchangeTransfer({
    required String stationAId,
    required String stationBId,
    required int transferWalkSeconds,
    String? walkingVector,
  }) {
    addEdge(GraphEdge(
      fromStationId: stationAId,
      toStationId: stationBId,
      lineId: null,
      travelTimeSeconds: transferWalkSeconds,
      distanceMeters: 50.0,
      type: EdgeType.transferWalk,
      walkingVector: walkingVector,
    ));
    addEdge(GraphEdge(
      fromStationId: stationBId,
      toStationId: stationAId,
      lineId: null,
      travelTimeSeconds: transferWalkSeconds,
      distanceMeters: 50.0,
      type: EdgeType.transferWalk,
      walkingVector: walkingVector,
    ));
  }

  Station? getStation(String id) => _stations[id];

  TransitLine? getLine(String id) => _lines[id];

  List<GraphEdge> getOutgoingEdges(String stationId) => _adjacency[stationId] ?? [];

  List<Station> getStationsForCity(String city) {
    final lower = city.toLowerCase();
    return _stations.values.where((s) => s.city.toLowerCase() == lower).toList();
  }

  /// Locates the geographically closest station to a given coordinate
  Station? findNearestStation(
    double lat,
    double lng, {
    String? city,
    double maxDistanceMeters = 50000, // 50km default radius
  }) {
    Station? nearest;
    double minDistance = double.infinity;

    for (final station in _stations.values) {
      if (city != null && station.city.toLowerCase() != city.toLowerCase()) {
        continue;
      }
      final dist = _haversineDistance(lat, lng, station.latitude, station.longitude);
      if (dist < minDistance && dist <= maxDistanceMeters) {
        minDistance = dist;
        nearest = station;
      }
    }
    return nearest;
  }

  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void clear() {
    _stations.clear;
    _lines.clear;
    _adjacency.clear;
  }
}
