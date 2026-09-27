import '../models/station.dart';
import '../models/transit_line.dart';
import '../models/graph_edge.dart';

enum DeltaAction {
  insertOrUpdate,
  delete,
}

class StationDelta {
  final DeltaAction action;
  final Station station;

  const StationDelta({required this.action, required this.station});
}

class EdgeDelta {
  final DeltaAction action;
  final GraphEdge edge;

  const EdgeDelta({required this.action, required this.edge});
}

class LineDelta {
  final DeltaAction action;
  final TransitLine line;

  const LineDelta({required this.action, required this.line});
}

class DeltaPayload {
  final int fromVersion;
  final int toVersion;
  final DateTime timestamp;
  final List<StationDelta> stationDeltas;
  final List<EdgeDelta> edgeDeltas;
  final List<LineDelta> lineDeltas;

  const DeltaPayload({
    required this.fromVersion,
    required this.toVersion,
    required this.timestamp,
    this.stationDeltas = const [],
    this.edgeDeltas = const [],
    this.lineDeltas = const [],
  });

  bool get isEmpty =>
      stationDeltas.isEmpty && edgeDeltas.isEmpty && lineDeltas.isEmpty;
}
