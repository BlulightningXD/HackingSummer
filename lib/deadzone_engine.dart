library deadzone_engine;

export 'models/station.dart';
export 'models/transit_line.dart';
export 'models/graph_edge.dart';
export 'models/route_result.dart';
export 'models/congestion.dart';
export 'graph/transit_graph.dart';
export 'graph/routing_algorithm.dart';
export 'storage/database_schema.dart';
export 'storage/graph_store.dart';
export 'storage/in_memory_graph_store.dart';
export 'storage/graph_store_resolver.dart';
export 'sync/delta_sync_models.dart';
export 'sync/heartbeat_detector.dart';
export 'sync/delta_sync_service.dart';
export 'sync/congestion_sync_manager.dart';
export 'data/city_registry.dart';
export 'data/delhi_metro_seed.dart';
export 'data/lucknow_metro_seed.dart';

import 'models/station.dart';
import 'models/transit_line.dart';
import 'models/route_result.dart';
import 'models/congestion.dart';
import 'graph/transit_graph.dart';
import 'graph/routing_algorithm.dart';
import 'storage/graph_store.dart';
import 'storage/graph_store_resolver.dart';
import 'sync/delta_sync_models.dart';
import 'sync/heartbeat_detector.dart';
import 'sync/delta_sync_service.dart';
import 'sync/congestion_sync_manager.dart';
import 'data/city_registry.dart';

class DeadzoneEngine {
  final GraphStore store;
  final TransitGraph graph;
  final HeartbeatDetector heartbeatDetector;
  late final DeltaSyncService syncService;
  late final CongestionSyncManager congestionManager;
  late final RoutingAlgorithm router;

  String _currentCity;

  String get currentCity => _currentCity;
  TransitGraph get activeGraph => graph;
  bool get isInDeadzone => heartbeatDetector.isInDeadzone;
  bool get isOnline => !heartbeatDetector.isInDeadzone;

  Stream<HeartbeatEvent> get onHeartbeat => heartbeatDetector.onHeartbeat;
  Stream<DeltaSyncResult> get onSyncComplete => syncService.onSyncComplete;
  Stream<CongestionSyncResult> get onCongestionSyncComplete =>
      congestionManager.onSyncComplete;
  Stream<CongestionRecord> get onCongestionBuffered =>
      congestionManager.onCongestionBuffered;

  int get pendingCongestionCount => congestionManager.pendingOutboxCount;

  DeadzoneEngine._({
    required this.store,
    required this.graph,
    required this.heartbeatDetector,
    required String initialCity,
    Future<DeltaPayload?> Function(int currentVersion)? deltaProvider,
    CongestionFlushCallback? onFlushCongestion,
    NetworkCongestionFetcher? onFetchNetworkCongestion,
    Duration congestionTtl = const Duration(minutes: 45),
  }) : _currentCity = initialCity {
    router = RoutingAlgorithm(graph);
    syncService = DeltaSyncService(
      store: store,
      graph: graph,
      heartbeatDetector: heartbeatDetector,
      deltaProvider: deltaProvider,
    );
    congestionManager = CongestionSyncManager(
      store: store,
      heartbeatDetector: heartbeatDetector,
      onFlushRemote: onFlushCongestion,
      onFetchRemote: onFetchNetworkCongestion,
      congestionTtl: congestionTtl,
    );
  }

  /// Initializes the Deadzone Offline Engine with SQLite / persistent storage
  static Future<DeadzoneEngine> initialize({
    String? sqlitePath,
    String defaultCity = CityRegistry.cityDelhi,
    bool preseedIfEmpty = true,
    Future<DeltaPayload?> Function(int currentVersion)? deltaProvider,
    CongestionFlushCallback? onFlushCongestion,
    NetworkCongestionFetcher? onFetchNetworkCongestion,
    Duration congestionTtl = const Duration(minutes: 45),
  }) async {
    final store = resolveGraphStore(path: sqlitePath);
    final heartbeatDetector = HeartbeatDetector();

    // Load graph from local SQLite store
    var graph = store.loadGraph(city: null);

    // If SQLite store is blank and preseed is enabled, populate initial networks
    if (graph.stationCount == 0 && preseedIfEmpty) {
      CityRegistry.populateAll(graph);
      store.saveGraph(graph);
      store.setSyncVersion(1);
    }

    return DeadzoneEngine._(
      store: store,
      graph: graph,
      heartbeatDetector: heartbeatDetector,
      initialCity: defaultCity,
      deltaProvider: deltaProvider,
      onFlushCongestion: onFlushCongestion,
      onFetchNetworkCongestion: onFetchNetworkCongestion,
      congestionTtl: congestionTtl,
    );
  }

  /// Calculates the optimal route completely offline in pure Dart
  RouteResult? findRoute({
    required String originStationId,
    required String destinationStationId,
    RoutingPreference preference = RoutingPreference.fastestTime,
    int transferPenaltySeconds = 240,
  }) {
    return router.findRoute(
      originStationId: originStationId,
      destinationStationId: destinationStationId,
      preference: preference,
      transferPenaltySeconds: transferPenaltySeconds,
    );
  }

  /// Finds the nearest station based on passenger GPS coordinates
  Station? findNearestStation(double latitude, double longitude) {
    return graph.findNearestStation(latitude, longitude, city: _currentCity);
  }

  /// Automatically switches the active transit city based on passenger coordinates
  String autoDetectCity(double latitude, double longitude) {
    final detected = CityRegistry.detectCity(latitude, longitude);
    if (detected.toLowerCase() != _currentCity.toLowerCase()) {
      switchCity(detected);
    }
    return _currentCity;
  }

  /// Switches active city network (e.g. 'Delhi' or 'Lucknow')
  void switchCity(String cityName) {
    _currentCity = cityName;
  }

  List<Station> getStationsForCurrentCity() {
    return graph.getStationsForCity(_currentCity);
  }

  List<TransitLine> getLinesForCurrentCity() {
    return graph.lines.values
        .where((l) => l.city.toLowerCase() == _currentCity.toLowerCase())
        .toList();
  }

  /// Buffers a local BLE crowd vicinity reading (0 to 100) while underground
  CongestionRecord recordCongestion({
    required String stationId,
    required int score,
    String? platformOrLine,
    DateTime? timestamp,
  }) {
    return congestionManager.recordCongestion(
      stationId: stationId,
      score: score,
      platformOrLine: platformOrLine,
      timestamp: timestamp,
    );
  }

  /// Retrieves the current crowd congestion snapshot for a station (returns null if > 45 mins stale)
  StationCongestionSnapshot? getStationCongestion(String stationId) {
    return congestionManager.getStationCongestion(stationId);
  }

  /// Retrieves all active non-stale congestion snapshots across the network
  Map<String, StationCongestionSnapshot> getAllStationCongestion() {
    return congestionManager.getAllStationCongestion();
  }

  /// Manually flushes the offline congestion outbox
  Future<CongestionSyncResult> flushCongestionOutbox() {
    return congestionManager.flushOutbox();
  }

  /// Simulates dropping into a deep underground station (e.g. Rajiv Chowk, Hauz Khas)
  void enterSubterraneanDeadzone({String note = 'Entered deep underground platform'}) {
    heartbeatDetector.enterDeadzone(note: note);
  }

  /// Triggers a cellular heartbeat pulse (e.g. surfacing at elevated station or 5G spike)
  void triggerCellularHeartbeat({String note = 'Surfaced at elevated station'}) {
    heartbeatDetector.triggerHeartbeat(note: note);
  }

  /// Manually executes a silent background delta-sync for graph topology
  Future<DeltaSyncResult> syncDeltas({DeltaPayload? manualPayload}) {
    return syncService.executeSilentSync(manualPayload: manualPayload);
  }

  void dispose() {
    congestionManager.dispose();
    syncService.dispose();
    heartbeatDetector.dispose();
    store.close();
  }
}
