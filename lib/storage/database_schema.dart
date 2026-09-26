class DatabaseSchema {
  static const String createStationsTable = '''
    CREATE TABLE IF NOT EXISTS stations (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      hindi_name TEXT,
      city TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      is_interchange INTEGER NOT NULL DEFAULT 0,
      depth_level INTEGER NOT NULL DEFAULT 0,
      is_deadzone INTEGER NOT NULL DEFAULT 0
    );
  ''';

  static const String createLinesTable = '''
    CREATE TABLE IF NOT EXISTS lines (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      city TEXT NOT NULL,
      color_hex TEXT NOT NULL,
      code TEXT NOT NULL
    );
  ''';

  static const String createStationLinesTable = '''
    CREATE TABLE IF NOT EXISTS station_lines (
      station_id TEXT NOT NULL,
      line_id TEXT NOT NULL,
      PRIMARY KEY (station_id, line_id),
      FOREIGN KEY (station_id) REFERENCES stations(id) ON DELETE CASCADE,
      FOREIGN KEY (line_id) REFERENCES lines(id) ON DELETE CASCADE
    );
  ''';

  static const String createEdgesTable = '''
    CREATE TABLE IF NOT EXISTS edges (
      from_id TEXT NOT NULL,
      to_id TEXT NOT NULL,
      line_id TEXT,
      travel_time_seconds INTEGER NOT NULL,
      distance_meters REAL NOT NULL,
      edge_type TEXT NOT NULL,
      walking_vector TEXT,
      PRIMARY KEY (from_id, to_id, line_id, edge_type)
    );
  ''';

  static const String createSyncMetaTable = '''
    CREATE TABLE IF NOT EXISTS sync_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''';

  static const String createCongestionOutboxTable = '''
    CREATE TABLE IF NOT EXISTS congestion_outbox (
      id TEXT PRIMARY KEY,
      station_id TEXT NOT NULL,
      score INTEGER NOT NULL,
      timestamp INTEGER NOT NULL,
      platform_or_line TEXT
    );
  ''';

  static const String createStationCongestionCacheTable = '''
    CREATE TABLE IF NOT EXISTS station_congestion_cache (
      station_id TEXT PRIMARY KEY,
      score INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  ''';

  static const List<String> createIndices = [
    'CREATE INDEX IF NOT EXISTS idx_stations_city ON stations(city);',
    'CREATE INDEX IF NOT EXISTS idx_stations_coords ON stations(latitude, longitude);',
    'CREATE INDEX IF NOT EXISTS idx_edges_from ON edges(from_id);',
    'CREATE INDEX IF NOT EXISTS idx_edges_to ON edges(to_id);',
    'CREATE INDEX IF NOT EXISTS idx_edges_line ON edges(line_id);',
    'CREATE INDEX IF NOT EXISTS idx_congestion_outbox_time ON congestion_outbox(timestamp);',
    'CREATE INDEX IF NOT EXISTS idx_station_congestion_time ON station_congestion_cache(updated_at);',
  ];
}
