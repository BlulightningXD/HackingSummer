import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../deadzone_engine.dart';

class BleCrowdScanner {
  final DeadzoneEngine engine;
  Timer? _scanTimer;
  bool _isScanning = false;

  BleCrowdScanner(this.engine);

  void startScanning() {
    if (_isScanning) return;
    _isScanning = true;
    _scanCycle();
    _scanTimer = Timer.periodic(const Duration(minutes: 1), (_) => _scanCycle());
  }

  void stopScanning() {
    _isScanning = false;
    _scanTimer?.cancel();
    FlutterBluePlus.stopScan();
  }

  Future<void> _scanCycle() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) return;

      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) return;

      final Set<String> uniqueDevices = {};

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          uniqueDevices.add(r.device.remoteId.str);
        }
      });

      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
      await subscription.cancel();

      // Convert device count to a crowd score (0-100)
      // Increased threshold to 200 to prevent false 100% scores in high device density areas
      final count = uniqueDevices.length;
      final score = (count / 200.0 * 100).clamp(0, 100).toInt();

      // Ensure we have location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      // Get nearest station using GPS
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      // Only record if we are within 2km of a station
      final nearest = engine.activeGraph.findNearestStation(
        position.latitude, 
        position.longitude, 
        city: engine.currentCity,
        maxDistanceMeters: 2000, 
      );

      if (nearest != null) {
        // Record congestion
        engine.recordCongestion(
          stationId: nearest.id,
          score: score,
          timestamp: DateTime.now(),
        );
        print('BLE Scanner: Found $count devices near ${nearest.name}. Logged score $score.');
      }
    } catch (e) {
      print('BLE Scan error: $e');
    }
  }
}
