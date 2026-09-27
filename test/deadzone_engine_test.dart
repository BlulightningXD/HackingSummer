import 'package:test/test.dart';
import 'package:deadzone_engine/deadzone_engine.dart';

void main() {
  group('DeadzoneEngine - Delhi Metro Routing & Offline Traversal', () {
    late DeadzoneEngine engine;

    setUp(() async {
      engine = await DeadzoneEngine.initialize(
        sqlitePath: null, // In-memory SQLite for test
        defaultCity: CityRegistry.cityDelhi,
        preseedIfEmpty: true,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('Initializes with Delhi and Lucknow Metro networks populated', () {
      expect(engine.graph.stationCount, greaterThan(30));
      expect(engine.graph.lineCount, greaterThanOrEqualTo(6));
      expect(engine.getStationsForCurrentCity().length, greaterThan(15));
    });

    test('Direct route along Yellow Line (Samaypur Badli to Rajiv Chowk)', () {
      final route = engine.findRoute(
        originStationId: 'delhi_samaypur_badli',
        destinationStationId: 'delhi_rajiv_chowk',
      );

      expect(route, isNotNull);
      expect(route!.interchangeCount, equals(0));
      expect(route.fullPath.first.id, equals('delhi_samaypur_badli'));
      expect(route.fullPath.last.id, equals('delhi_rajiv_chowk'));
      expect(route.passesThroughDeadzone, isTrue); // Passes through Chawri Bazar / Chandni Chowk
    });

    test('Interchange route from Yellow Line to Blue Line via Rajiv Chowk', () {
      // From Azadpur (Yellow) to Karol Bagh (Blue)
      final route = engine.findRoute(
        originStationId: 'delhi_azadpur',
        destinationStationId: 'delhi_karol_bagh',
      );

      expect(route, isNotNull);
      expect(route!.interchangeCount, greaterThanOrEqualTo(1));
      // Must pass through Rajiv Chowk interchange
      final stationIds = route.fullPath.map((s) => s.id).toList();
      expect(stationIds, contains('delhi_rajiv_chowk'));
      expect(route.segments.length, greaterThanOrEqualTo(2));
    });

    test('Route to India\'s deepest metro station: Hauz Khas', () {
      final route = engine.findRoute(
        originStationId: 'delhi_kashmere_gate',
        destinationStationId: 'delhi_hauz_khas',
      );

      expect(route, isNotNull);
      final deadzoneNames = route!.deadzoneStations.map((s) => s.name).toList();
      expect(deadzoneNames, contains('Hauz Khas'));
      expect(deadzoneNames, contains('Chawri Bazar'));
    });
  });

  group('DeadzoneEngine - Lucknow Metro & Multi-City Detection', () {
    late DeadzoneEngine engine;

    setUp(() async {
      engine = await DeadzoneEngine.initialize(preseedIfEmpty: true);
    });

    tearDown(() {
      engine.dispose();
    });

    test('Auto-detects Lucknow Metro from Lucknow GPS coordinates', () {
      // Coordinates near Hazratganj, Lucknow: 26.8520° N, 80.9390° E
      final detected = engine.autoDetectCity(26.8520, 80.9390);
      expect(detected, equals(CityRegistry.cityLucknow));
      expect(engine.currentCity, equals(CityRegistry.cityLucknow));

      final lucknowStations = engine.getStationsForCurrentCity();
      expect(lucknowStations.length, greaterThanOrEqualTo(20));

      final stationNames = lucknowStations.map((s) => s.name).toList();
      expect(stationNames, contains('Charbagh Railway Station'));
      expect(stationNames, contains('Hazratganj'));
      expect(stationNames, contains('Munshi Pulia'));
    });

    test('Finds route on Lucknow Red Line (Airport to Munshi Pulia)', () {
      engine.switchCity(CityRegistry.cityLucknow);

      final route = engine.findRoute(
        originStationId: 'lko_ccs_airport',
        destinationStationId: 'lko_munshi_pulia',
      );

      expect(route, isNotNull);
      expect(route!.interchangeCount, equals(0)); // Direct line
      expect(route.fullPath.first.id, equals('lko_ccs_airport'));
      expect(route.fullPath.last.id, equals('lko_munshi_pulia'));
      expect(route.passesThroughDeadzone, isTrue); // Passes Hazratganj/Sachivalaya underground
    });
  });

  group('DeadzoneEngine - Heartbeat & Delta Sync', () {
    late DeadzoneEngine engine;

    setUp(() async {
      engine = await DeadzoneEngine.initialize(preseedIfEmpty: true);
    });

    tearDown(() {
      engine.dispose();
    });

    test('Tracks subterranean deadzone entry and signal restoration', () async {
      expect(engine.isOnline, isTrue);

      engine.enterSubterraneanDeadzone(note: 'Entering Rajiv Chowk Level -2');
      expect(engine.isInDeadzone, isTrue);
      expect(engine.isOnline, isFalse);

      final heartbeatFuture = engine.onHeartbeat.first;
      engine.triggerCellularHeartbeat(note: 'Surfaced at Patel Chowk');

      final event = await heartbeatFuture;
      expect(event.isRestored, isTrue);
      expect(engine.isOnline, isTrue);
    });

    test('Applies hot delta synchronization into in-memory graph and SQLite', () async {
      final initialVersion = engine.store.getSyncVersion();

      // Create a new infill station via delta
      const newStation = Station(
        id: 'delhi_new_infill_stn',
        name: 'Aerocity Infill Hub',
        city: 'Delhi',
        latitude: 28.5500,
        longitude: 77.1200,
        lineIds: ['delhi_airport'],
      );

      final delta = DeltaPayload(
        fromVersion: initialVersion,
        toVersion: initialVersion + 1,
        timestamp: DateTime.now(),
        stationDeltas: const [
          StationDelta(action: DeltaAction.insertOrUpdate, station: newStation),
        ],
      );

      final syncResult = await engine.syncDeltas(manualPayload: delta);
      expect(syncResult.success, isTrue);
      expect(syncResult.appliedVersion, equals(initialVersion + 1));
      expect(engine.graph.getStation('delhi_new_infill_stn'), isNotNull);
      expect(engine.store.getSyncVersion(), equals(initialVersion + 1));
    });
  });
}
