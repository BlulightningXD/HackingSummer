import 'package:sqlite3/sqlite3.dart';
import 'in_memory_graph_store.dart';
import '../models/station.dart';
import '../models/transit_line.dart';
import '../models/graph_edge.dart';
import '../models/congestion.dart';
import '../graph/transit_graph.dart';
import 'database_schema.dart';
import 'graph_store.dart';

class SqliteGraphStore implements GraphStore {
  final Database _db;

  SqliteGraphStore(this._db) {
    _initializeSchema();
  }

  /// Factory for persistent SQLite file on disk
  factory SqliteGraphStore.openFile(String path) {
    final db = sqlite3.open(path);
    return SqliteGraphStore(db);
  }

  /// Factory for in-memory SQLite (great for testing & fast caching)
  factory SqliteGraphStore.inMemory() {
    final db = sqlite3.openInMemory();
    return SqliteGraphStore(db);
  }

  void _initializeSchema() {
    _db.execute('PRAGMA foreign_keys = ON;');
    _db.execute(DatabaseSchema.createStationsTable);
    _db.execute(DatabaseSchema.createLinesTable);
    _db.execute(DatabaseSchema.createStationLinesTable);
    _db.execute(DatabaseSchema.createEdgesTable);
    _db.execute(DatabaseSchema.createSyncMetaTable);
    _db.execute(DatabaseSchema.createCongestionOutboxTable);
    _db.execute(DatabaseSchema.createStationCongestionCacheTable);

    for (final indexSql in DatabaseSchema.createIndices) {
      _db.execute(indexSql);
    }
  }

  /// Atomically persists an entire TransitGraph into the local SQLite store
  @override
  void saveGraph(TransitGraph graph) {
    _db.execute('BEGIN TRANSACTION;');
    try {
      final lineStmt = _db.prepare(
        'INSERT OR REPLACE INTO lines (id, name, city, color_hex, code) VALUES (?, ?, ?, ?, ?);',
      );
      for (final line in graph.lines.values) {
        lineStmt.execute([line.id, line.name, line.city, line.colorHex, line.code]);
      }
      lineStmt.dispose();

      final stationStmt = _db.prepare(
        'INSERT OR REPLACE INTO stations (id, name, hindi_name, city, latitude, longitude, is_interchange, depth_level, is_deadzone) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
      );
      final stationLineStmt = _db.prepare(
        'INSERT OR REPLACE INTO station_lines (station_id, line_id) VALUES (?, ?);',
      );

      for (final station in graph.stations.values) {
        stationStmt.execute([
          station.id,
          station.name,
          station.hindiName,
          station.city,
          station.latitude,
          station.longitude,
          station.isInterchange ? 1 : 0,
          station.undergroundDepthLevel,
          station.isDeadzone ? 1 : 0,
        ]);

        for (final lineId in station.lineIds) {
          stationLineStmt.execute([station.id, lineId]);
        }
      }
      stationStmt.dispose();
      stationLineStmt.dispose();

      final edgeStmt = _db.prepare(
        'INSERT OR REPLACE INTO edges (from_id, to_id, line_id, travel_time_seconds, distance_meters, edge_type, walking_vector) VALUES (?, ?, ?, ?, ?, ?, ?);',
      );

      for (final edges in graph.adjacency.values) {
        for (final edge in edges) {
          edgeStmt.execute([
            edge.fromStationId,
            edge.toStationId,
            edge.lineId,
            edge.travelTimeSeconds,
            edge.distanceMeters,
            edge.type.name,
            edge.walkingVector,
          ]);
        }
      }
      edgeStmt.dispose();

      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Loads stations, lines, and edges from SQLite into a TransitGraph instance
  @override
  TransitGraph loadGraph({String? city}) {
    final graph = TransitGraph();

    // 1. Load Lines
    String linesSql = 'SELECT * FROM lines';
    List<Object?> linesParams = [];
    if (city != null) {
      linesSql += ' WHERE LOWER(city) = LOWER(?)';
      linesParams.add(city);
    }
    final lineRows = _db.select(linesSql, linesParams);
    for (final row in lineRows) {
      graph.addLine(TransitLine(
        id: row['id'] as String,
        name: row['name'] as String,
        city: row['city'] as String,
        colorHex: row['color_hex'] as String,
        code: row['code'] as String,
      ));
    }

    // 2. Load Stations with their assigned lines
    String stationsSql = 'SELECT * FROM stations';
    List<Object?> stationParams = [];
    if (city != null) {
      stationsSql += ' WHERE LOWER(city) = LOWER(?)';
      stationParams.add(city);
    }
    final stationRows = _db.select(stationsSql, stationParams);

    for (final row in stationRows) {
      final sId = row['id'] as String;
      final lineRowsForStation = _db.select(
        'SELECT line_id FROM station_lines WHERE station_id = ?',
        [sId],
      );
      final lines = lineRowsForStation.map((r) => r['line_id'] as String).toList();

      graph.addStation(Station(
        id: sId,
        name: row['name'] as String,
        hindiName: row['hindi_name'] as String?,
        city: row['city'] as String,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        lineIds: lines,
        isInterchange: (row['is_interchange'] as int) == 1,
        undergroundDepthLevel: (row['depth_level'] as int?) ?? 0,
        isDeadzone: (row['is_deadzone'] as int?) == 1,
      ));
    }

    // 3. Load Edges
    final edgeRows = _db.select('SELECT * FROM edges');
    for (final row in edgeRows) {
      final fromId = row['from_id'] as String;
      final toId = row['to_id'] as String;

      // Only add edge if both stations exist in our active graph
      if (graph.stations.containsKey(fromId) && graph.stations.containsKey(toId)) {
        graph.addEdge(GraphEdge(
          fromStationId: fromId,
          toStationId: toId,
          lineId: row['line_id'] as String?,
          travelTimeSeconds: row['travel_time_seconds'] as int,
          distanceMeters: (row['distance_meters'] as num).toDouble(),
          type: EdgeType.values.firstWhere(
            (e) => e.name == row['edge_type'],
            orElse: () => EdgeType.rail,
          ),
          walkingVector: row['walking_vector'] as String?,
        ));
      }
    }

    return graph;
  }

  @override
  int getSyncVersion() {
    final rows = _db.select("SELECT value FROM sync_meta WHERE key = 'graph_version'");
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['value'] as String) ?? 0;
  }

  @override
  void setSyncVersion(int version) {
    _db.execute(
      "INSERT OR REPLACE INTO sync_meta (key, value, updated_at) VALUES ('graph_version', ?, ?);",
      [version.toString(), DateTime.now().millisecondsSinceEpoch],
    );
  }

  @override
  void queueOutboxCongestion(CongestionRecord record) {
    _db.execute(
      '''
      INSERT OR REPLACE INTO congestion_outbox (id, station_id, score, timestamp, platform_or_line)
      VALUES (?, ?, ?, ?, ?);
      ''',
      [
        record.id,
        record.stationId,
        record.score,
        record.timestamp.millisecondsSinceEpoch,
        record.platformOrLine,
      ],
    );
  }

  @override
  List<CongestionRecord> getPendingOutboxCongestion() {
    final rows = _db.select('SELECT * FROM congestion_outbox ORDER BY timestamp ASC;');
    return rows.map((row) {
      return CongestionRecord(
        id: row['id'] as String,
        stationId: row['station_id'] as String,
        score: row['score'] as int,
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        platformOrLine: row['platform_or_line'] as String?,
      );
    }).toList();
  }

  @override
  void clearOutboxCongestion(List<String> ids) {
    if (ids.isEmpty) return;
    _db.execute('BEGIN TRANSACTION;');
    try {
      final stmt = _db.prepare('DELETE FROM congestion_outbox WHERE id = ?;');
      for (final id in ids) {
        stmt.execute([id]);
      }
      stmt.dispose();
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  @override
  void updateStationCongestion(String stationId, int score, DateTime timestamp) {
    _db.execute(
      '''
      INSERT OR REPLACE INTO station_congestion_cache (station_id, score, updated_at)
      VALUES (?, ?, ?);
      ''',
      [
        stationId,
        score.clamp(0, 100),
        timestamp.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  StationCongestionSnapshot? getStationCongestion(
    String stationId, {
    Duration timeout = const Duration(minutes: 45),
  }) {
    final rows = _db.select(
      'SELECT * FROM station_congestion_cache WHERE station_id = ?;',
      [stationId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final snapshot = StationCongestionSnapshot(
      stationId: row['station_id'] as String,
      score: row['score'] as int,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
    if (snapshot.isStale(timeout: timeout)) return null;
    return snapshot;
  }

  @override
  Map<String, StationCongestionSnapshot> getAllStationCongestion({
    Duration timeout = const Duration(minutes: 45),
  }) {
    final rows = _db.select('SELECT * FROM station_congestion_cache;');
    final map = <String, StationCongestionSnapshot>{};
    for (final row in rows) {
      final snapshot = StationCongestionSnapshot(
        stationId: row['station_id'] as String,
        score: row['score'] as int,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      );
      if (!snapshot.isStale(timeout: timeout)) {
        map[snapshot.stationId] = snapshot;
      }
    }
    return map;
  }

  @override
  void close() {
    _db.dispose();
  }
}

GraphStore createPlatformGraphStore({String? path}) {
  try {
    if (path != null && path.isNotEmpty) {
      return SqliteGraphStore.openFile(path);
    }
    return SqliteGraphStore.inMemory();
  } catch (e) {
    print('SQLite FFI missing, falling back to pure Dart InMemoryGraphStore: $e');
    return InMemoryGraphStore();
  }
}
