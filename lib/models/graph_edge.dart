enum EdgeType {
  rail,
  transferWalk,
  pedestrianLink,
}

class GraphEdge {
  final String fromStationId;
  final String toStationId;
  final String? lineId;
  final int travelTimeSeconds;
  final double distanceMeters;
  final EdgeType type;
  final String? walkingVector;

  const GraphEdge({
    required this.fromStationId,
    required this.toStationId,
    this.lineId,
    required this.travelTimeSeconds,
    required this.distanceMeters,
    this.type = EdgeType.rail,
    this.walkingVector,
  });

  Map<String, dynamic> toMap() {
    return {
      'from_id': fromStationId,
      'to_id': toStationId,
      'line_id': lineId,
      'travel_time_seconds': travelTimeSeconds,
      'distance_meters': distanceMeters,
      'edge_type': type.name,
      'walking_vector': walkingVector,
    };
  }

  factory GraphEdge.fromMap(Map<String, dynamic> map) {
    return GraphEdge(
      fromStationId: map['from_id'] as String,
      toStationId: map['to_id'] as String,
      lineId: map['line_id'] as String?,
      travelTimeSeconds: map['travel_time_seconds'] as int,
      distanceMeters: (map['distance_meters'] as num).toDouble(),
      type: EdgeType.values.firstWhere(
        (e) => e.name == map['edge_type'],
        orElse: () => EdgeType.rail,
      ),
      walkingVector: map['walking_vector'] as String?,
    );
  }

  @override
  String toString() =>
      '$fromStationId -> $toStationId (${type.name}, ${travelTimeSeconds}s)';
}
