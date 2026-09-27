import 'dart:async';
import '../storage/graph_store.dart';
import '../graph/transit_graph.dart';
import 'delta_sync_models.dart';
import 'heartbeat_detector.dart';

class DeltaSyncResult {
  final bool success;
  final int appliedVersion;
  final int changesCount;
  final String message;

  const DeltaSyncResult({
    required this.success,
    required this.appliedVersion,
    required this.changesCount,
    required this.message,
  });
}

class DeltaSyncService {
  final GraphStore store;
  final TransitGraph graph;
  final HeartbeatDetector heartbeatDetector;
  final Future<DeltaPayload?> Function(int currentVersion)? deltaProvider;

  StreamSubscription<HeartbeatEvent>? _heartbeatSub;
  bool _isSyncing = false;

  final _syncStreamController = StreamController<DeltaSyncResult>.broadcast();
  Stream<DeltaSyncResult> get onSyncComplete => _syncStreamController.stream;

  DeltaSyncService({
    required this.store,
    required this.graph,
    required this.heartbeatDetector,
    this.deltaProvider,
  }) {
    _startHeartbeatListener();
  }

  void _startHeartbeatListener() {
    _heartbeatSub = heartbeatDetector.onSignalRestored.listen((event) async {
      // Trigger silent background sync on cellular heartbeat
      await executeSilentSync();
    });
  }

  /// Triggers a silent delta-sync against the remote provider or provided payload
  Future<DeltaSyncResult> executeSilentSync({DeltaPayload? manualPayload}) async {
    if (_isSyncing) {
      return const DeltaSyncResult(
        success: false,
        appliedVersion: 0,
        changesCount: 0,
        message: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    try {
      final currentVersion = store.getSyncVersion();

      final payload = manualPayload ??
          (deltaProvider != null ? await deltaProvider!(currentVersion) : null);

      if (payload == null || payload.isEmpty) {
        final res = DeltaSyncResult(
          success: true,
          appliedVersion: currentVersion,
          changesCount: 0,
          message: 'Graph up to date at v$currentVersion',
        );
        _syncStreamController.add(res);
        return res;
      }

      int changes = 0;

      // Apply Station updates
      for (final sDelta in payload.stationDeltas) {
        if (sDelta.action == DeltaAction.insertOrUpdate) {
          graph.addStation(sDelta.station);
          changes++;
        }
      }

      // Apply Line updates
      for (final lDelta in payload.lineDeltas) {
        if (lDelta.action == DeltaAction.insertOrUpdate) {
          graph.addLine(lDelta.line);
          changes++;
        }
      }

      // Apply Edge updates (e.g. temporary track closure or speed restriction)
      for (final eDelta in payload.edgeDeltas) {
        if (eDelta.action == DeltaAction.insertOrUpdate) {
          graph.addEdge(eDelta.edge);
          changes++;
        }
      }

      // Persist hot updates atomically into local SQLite
      store.saveGraph(graph);
      store.setSyncVersion(payload.toVersion);

      final result = DeltaSyncResult(
        success: true,
        appliedVersion: payload.toVersion,
        changesCount: changes,
        message: 'Applied $changes updates (v${payload.fromVersion} -> v${payload.toVersion})',
      );
      _syncStreamController.add(result);
      return result;
    } catch (e) {
      final errorResult = DeltaSyncResult(
        success: false,
        appliedVersion: store.getSyncVersion(),
        changesCount: 0,
        message: 'Sync error: $e',
      );
      _syncStreamController.add(errorResult);
      return errorResult;
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _heartbeatSub?.cancel();
    _syncStreamController.close();
  }
}
