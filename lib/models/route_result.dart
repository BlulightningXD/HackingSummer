import 'station.dart';
import 'transit_line.dart';
import 'graph_edge.dart';

class RouteSegment {
  final TransitLine? line;
  final Station fromStation;
  final Station toStation;
  final List<Station> stations;
  final int durationSeconds;
  final EdgeType type;
  final String? walkingVector;

  const RouteSegment({
    this.line,
    required this.fromStation,
    required this.toStation,
    required this.stations,
    required this.durationSeconds,
    required this.type,
    this.walkingVector,
  });

  bool get isTransfer => type == EdgeType.transferWalk || type == EdgeType.pedestrianLink;
}

class RouteResult {
  final Station origin;
  final Station destination;
  final List<Station> fullPath;
  final List<RouteSegment> segments;
  final int totalDurationSeconds;
  final int interchangeCount;
  final List<Station> deadzoneStations;

  const RouteResult({
    required this.origin,
    required this.destination,
    required this.fullPath,
    required this.segments,
    required this.totalDurationSeconds,
    required this.interchangeCount,
    required this.deadzoneStations,
  });

  int get totalMinutes => (totalDurationSeconds / 60).ceil();

  bool get passesThroughDeadzone => deadzoneStations.isNotEmpty;

  String get summary {
    final lineNames = segments
        .where((s) => !s.isTransfer && s.line != null)
        .map((s) => s.line!.name)
        .toSet()
        .join(' ➔ ');
    return '$lineNames ($totalMinutes mins, $interchangeCount transfer${interchangeCount == 1 ? '' : 's'})';
  }
}
