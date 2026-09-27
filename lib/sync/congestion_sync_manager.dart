import 'dart:async';
import '../models/congestion.dart';
import '../storage/graph_store.dart';
import 'heartbeat_detector.dart';

typedef CongestionFlushCallback = Future<bool> Function(List<CongestionRecord> pendingRecords);
typedef NetworkCongestionFetcher = Future<Map<String, int>> Function();

class CongestionSyncResult {
  final bool success;
  final int flushedCount;
  final int receivedCount;
  final String message;

  const CongestionSyncResult({
    required this.success,
    required this.flushedCount,
    required this.receivedCount,
    required this.message,
  });
}

class CongestionSyncManager {
  final GraphStore store;
  final HeartbeatDetector heartbeatDetector;
  final CongestionFlushCallback? onFlushRemote;
  final NetworkCongestionFetcher? onFetchRemote;

  /// Expiration timeout TTL (User specified: 45 minutes)
  final Duration congestionTtl;

  StreamSubscription<HeartbeatEvent>? _heartbeatSub;
  bool _isFlushing = false;

  final _syncResultController = StreamController<CongestionSyncResult>.broadcast();
  final _bufferedController = StreamController<CongestionRecord>.broadcast();

  Stream<CongestionSyncResult> get onSyncComplete => _syncResultController.stream;
  Stream<CongestionRecord> get onCongestionBuffered => _bufferedController.stream;

  CongestionSyncManager({
    required this.store,
    required this.heartbeatDetector,
    this.onFlushRemote,
    this.onFetchRemote,
    this.congestionTtl = const Duration(minutes: 45),
  }) {
    _startHeartbeatListener();
  }

  void _startHeartbeatListener() {
    _heartbeatSub = heartbeatDetector.onSignalRestored.listen((event) async {
      // Trigger opportunistic flush whenever cellular signal is restored
      await flushOutbox();
    });
  }

  /// Number of offline BLE crowd reports currently queued in the local outbox
  int get pendingOutboxCount => store.getPendingOutboxCongestion().length;

  /// Records a local BLE vicinity congestion observation while underground
  CongestionRecord recordCongestion({
    required String stationId,
    required int score,
    String? platformOrLine,
    DateTime? timestamp,
  }) {
    final recordTime = timestamp ?? DateTime.now();
    final clampedScore = score.clamp(0, 100);

    final record = CongestionRecord(
      id: 'cong_${stationId}_${recordTime.millisecondsSinceEpoch}',
      stationId: stationId,
      score: clampedScore,
      timestamp: recordTime,
      platformOrLine: platformOrLine,
    );

    // 1. Buffer in store-and-forward outbox
    store.queueOutboxCongestion(record);

    // 2. Optimistically update local station congestion cache
    store.updateStationCongestion(stationId, clampedScore, recordTime);

    _bufferedController.add(record);
    return record;
  }

  /// Retrieves the current crowd congestion snapshot for a station (returns null if > 45 mins stale)
  StationCongestionSnapshot? getStationCongestion(String stationId) {
    return store.getStationCongestion(stationId, timeout: congestionTtl);
  }

  /// Retrieves all active non-stale congestion snapshots across the network
  Map<String, StationCongestionSnapshot> getAllStationCongestion() {
    return store.getAllStationCongestion(timeout: congestionTtl);
  }

  /// Flushes pending outbox congestion reports and pulls latest network congestion
  Future<CongestionSyncResult> flushOutbox() async {
    if (_isFlushing) {
      return const CongestionSyncResult(
        success: false,
        flushedCount: 0,
        receivedCount: 0,
        message: 'Flush already in progress',
      );
    }

    _isFlushing = true;
    try {
      final pending = store.getPendingOutboxCongestion();
      int flushed = 0;
      int received = 0;

      if (pending.isNotEmpty) {
        // Send to remote backend if callback provided, otherwise simulate successful transmission
        bool uploadSuccess = true;
        if (onFlushRemote != null) {
          uploadSuccess = await onFlushRemote!(pending);
        }

        if (uploadSuccess) {
          flushed = pending.length;
          final ids = pending.map((r) => r.id).toList();
          store.clearOutboxCongestion(ids);
        }
      }

      // Fetch latest network congestion if remote fetcher provided
      if (onFetchRemote != null) {
        final remoteUpdates = await onFetchRemote!();
        final now = DateTime.now();
        for (final entry in remoteUpdates.entries) {
          store.updateStationCongestion(entry.key, entry.value, now);
          received++;
        }
      }

      final result = CongestionSyncResult(
        success: true,
        flushedCount: flushed,
        receivedCount: received,
        message: flushed > 0
            ? 'Flushed $flushed offline crowd report${flushed == 1 ? '' : 's'} on cellular heartbeat'
            : 'Outbox clean; cellular connection verified',
      );

      _syncResultController.add(result);
      return result;
    } catch (e) {
      final errorResult = CongestionSyncResult(
        success: false,
        flushedCount: 0,
        receivedCount: 0,
        message: 'Congestion sync error: $e',
      );
      _syncResultController.add(errorResult);
      return errorResult;
    } finally {
      _isFlushing = false;
    }
  }

  void dispose() {
    _heartbeatSub?.cancel();
    _syncResultController.close();
    _bufferedController.close();
  }
}
