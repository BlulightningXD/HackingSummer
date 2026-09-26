import 'dart:math' as math;

class Station {
  final String id;
  final String name;
  final String? hindiName;
  final String city;
  final double latitude;
  final double longitude;
  final List<String> lineIds;
  final bool isInterchange;
  final int undergroundDepthLevel; // 0 = Elevated/At-Grade, 1 = Sub-surface, 2+ = Deep Underground
  final bool isDeadzone; // True if station is a subterranean cellular deadzone

  const Station({
    required this.id,
    required this.name,
    this.hindiName,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.lineIds,
    this.isInterchange = false,
    this.undergroundDepthLevel = 0,
    this.isDeadzone = false,
  });

  /// Haversine distance in meters to another station
  double distanceTo(Station other) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(other.latitude - latitude);
    final dLon = _toRadians(other.longitude - longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(latitude)) *
            math.cos(_toRadians(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hindi_name': hindiName,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'is_interchange': isInterchange ? 1 : 0,
      'depth_level': undergroundDepthLevel,
      'is_deadzone': isDeadzone ? 1 : 0,
    };
  }

  factory Station.fromMap(Map<String, dynamic> map, List<String> lines) {
    return Station(
      id: map['id'] as String,
      name: map['name'] as String,
      hindiName: map['hindi_name'] as String?,
      city: map['city'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      lineIds: lines,
      isInterchange: (map['is_interchange'] as int) == 1,
      undergroundDepthLevel: (map['depth_level'] as int?) ?? 0,
      isDeadzone: (map['is_deadzone'] as int?) == 1,
    );
  }

  @override
  String toString() => '$name ($city, ${lineIds.join('/')})';
}
