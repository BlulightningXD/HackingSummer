enum CongestionBand {
  low, // 0 - 25: Clear / Plenty of seating
  moderate, // 26 - 60: Normal crowd / Standing room available
  heavy, // 61 - 85: Crowded / Busy platform
  severe, // 86 - 100: Overcrowded / Peak rush
}

extension CongestionBandX on CongestionBand {
  String get label {
    switch (this) {
      case CongestionBand.low:
        return 'Low (0-25%)';
      case CongestionBand.moderate:
        return 'Moderate (26-60%)';
      case CongestionBand.heavy:
        return 'Heavy (61-85%)';
      case CongestionBand.severe:
        return 'Severe Rush (86-100%)';
    }
  }

  String get colorHex {
    switch (this) {
      case CongestionBand.low:
        return '#10B981'; // Emerald Green
      case CongestionBand.moderate:
        return '#FACC15'; // Yellow
      case CongestionBand.heavy:
        return '#F97316'; // Orange
      case CongestionBand.severe:
        return '#EF4444'; // Red
    }
  }
}

class CongestionRecord {
  final String id;
  final String stationId;
  final int score; // 0 to 100
  final DateTime timestamp;
  final String? platformOrLine;

  CongestionRecord({
    required this.id,
    required this.stationId,
    required int score,
    required this.timestamp,
    this.platformOrLine,
  }) : score = score.clamp(0, 100);

  CongestionBand get band {
    if (score <= 25) return CongestionBand.low;
    if (score <= 60) return CongestionBand.moderate;
    if (score <= 85) return CongestionBand.heavy;
    return CongestionBand.severe;
  }

  /// Checks if this report has exceeded the offline timeout TTL (default: 45 minutes)
  bool isExpired({Duration timeout = const Duration(minutes: 45), DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(timestamp) > timeout;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'station_id': stationId,
      'score': score,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'platform_or_line': platformOrLine,
    };
  }

  factory CongestionRecord.fromMap(Map<String, dynamic> map) {
    return CongestionRecord(
      id: map['id'] as String,
      stationId: map['station_id'] as String,
      score: map['score'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      platformOrLine: map['platform_or_line'] as String?,
    );
  }

  @override
  String toString() =>
      'CongestionRecord($stationId: $score% at ${timestamp.toIso8601String()})';
}

class StationCongestionSnapshot {
  final String stationId;
  final int score; // 0 to 100
  final DateTime updatedAt;

  StationCongestionSnapshot({
    required this.stationId,
    required int score,
    required this.updatedAt,
  }) : score = score.clamp(0, 100);

  CongestionBand get band {
    if (score <= 25) return CongestionBand.low;
    if (score <= 60) return CongestionBand.moderate;
    if (score <= 85) return CongestionBand.heavy;
    return CongestionBand.severe;
  }

  /// Checks if this cached snapshot has exceeded the 45-minute timeout TTL
  bool isStale({Duration timeout = const Duration(minutes: 45), DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(updatedAt) > timeout;
  }
}
