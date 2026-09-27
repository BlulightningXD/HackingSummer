import 'package:test/test.dart';
import 'package:deadzone_engine/deadzone_engine.dart';

void main() {
  group('DeadzoneEngine - Subterranean Congestion Queue & Sync', () {
    late DeadzoneEngine engine;

    setUp(() async {
      engine = await DeadzoneEngine.initialize(
        sqlitePath: null, // In-memory
        defaultCity: CityRegistry.cityDelhi,
        preseedIfEmpty: true,
        congestionTtl: const Duration(minutes: 45),
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('Clamps congestion scores between 0 and 100', () {
      final recordUnder = engine.recordCongestion(
        stationId: 'delhi_rajiv_chowk',
        score: -15, // Negative
      );
      expect(recordUnder.score, equals(0));
      expect(recordUnder.band, equals(CongestionBand.low));

      final recordOver = engine.recordCongestion(
        stationId: 'delhi_hauz_khas',
        score: 145, // Above 100
      );
      expect(recordOver.score, equals(100));
      expect(recordOver.band, equals(CongestionBand.severe));
    });

    test('Buffers crowd readings in outbox while in underground deadzone', () {
      engine.enterSubterraneanDeadzone(note: 'Rajiv Chowk Level -2 Deadzone');
      expect(engine.isInDeadzone, isTrue);
      expect(engine.pendingCongestionCount, equals(0));

      // Teammate 1 BLE vicinity detects heavy crowd
      engine.recordCongestion(
        stationId: 'delhi_rajiv_chowk',
        score: 75,
        platformOrLine: 'Yellow Line Platform 1',
      );

      // Another reading at Chawri Bazar
      engine.recordCongestion(
        stationId: 'delhi_chawri_bazar',
        score: 90,
      );

      expect(engine.pendingCongestionCount, equals(2));

      // Reading is immediately available locally
      final cached = engine.getStationCongestion('delhi_rajiv_chowk');
      expect(cached, isNotNull);
      expect(cached!.score, equals(75));
      expect(cached.band, equals(CongestionBand.heavy));
    });

    test('Congestion data expires after 45-minute timeout TTL', () {
      final now = DateTime.now();

      // Fresh reading (5 minutes old)
      engine.recordCongestion(
        stationId: 'delhi_aiims',
        score: 40,
        timestamp: now.subtract(const Duration(minutes: 5)),
      );

      // Stale reading (50 minutes old, past 45-min TTL)
      engine.recordCongestion(
        stationId: 'delhi_kashmere_gate',
        score: 85,
        timestamp: now.subtract(const Duration(minutes: 50)),
      );

      // Fresh reading is returned
      final fresh = engine.getStationCongestion('delhi_aiims');
      expect(fresh, isNotNull);
      expect(fresh!.score, equals(40));

      // Stale reading > 45 minutes returns null
      final stale = engine.getStationCongestion('delhi_kashmere_gate');
      expect(stale, isNull);
    });

    test('Flushes outbox automatically when cellular heartbeat pulse is detected', () async {
      engine.enterSubterraneanDeadzone();

      // Queue 3 offline reports
      engine.recordCongestion(stationId: 'delhi_chawri_bazar', score: 88);
      engine.recordCongestion(stationId: 'delhi_rajiv_chowk', score: 65);
      engine.recordCongestion(stationId: 'delhi_patel_chowk', score: 20);

      expect(engine.pendingCongestionCount, equals(3));

      // Listen for sync completion event
      final syncFuture = engine.onCongestionSyncComplete.first;

      // Train surfaces at elevated station -> cellular heartbeat fires!
      engine.triggerCellularHeartbeat(note: 'Surfaced at Patel Chowk');

      final result = await syncFuture;
      expect(result.success, isTrue);
      expect(result.flushedCount, equals(3));
      expect(engine.pendingCongestionCount, equals(0)); // Outbox is completely clean
    });

    test('Fetches inbound network congestion snapshot and updates local cache', () async {
      final remoteData = {
        'delhi_dwarka_sec_21': 35,
        'delhi_botanical_garden': 80,
      };

      final customEngine = await DeadzoneEngine.initialize(
        defaultCity: CityRegistry.cityDelhi,
        preseedIfEmpty: true,
        onFetchNetworkCongestion: () async => remoteData,
      );

      final result = await customEngine.flushCongestionOutbox();
      expect(result.success, isTrue);
      expect(result.receivedCount, equals(2));

      final dwarka = customEngine.getStationCongestion('delhi_dwarka_sec_21');
      expect(dwarka, isNotNull);
      expect(dwarka!.score, equals(35));
      expect(dwarka.band, equals(CongestionBand.moderate));

      customEngine.dispose();
    });
  });
}
