# Deadzone Offline Engine (`deadzone_engine`)

> **Autonomous Subterranean Transit Graph, Offline A* Router, & Store-and-Forward BLE Congestion Delta-Sync**

---

## 🚉 The Problem It Solves

Anyone riding deep underground transit systems (e.g. **Rajiv Chowk**, **Hauz Khas**, **Chawri Bazar**, or **Hazratganj**) experiences total cellular blackouts. Satellite GPS cannot penetrate concrete and subterranean rock.

If an application depends on continuous cloud pings:
1. **Network calls hang and fail**, freezing the UI.
2. **Passenger BLE crowd detections cannot be sent to the cloud** while in underground platforms.
3. **Passengers cannot compute alternative routes** or view transfer vectors.

The `deadzone_engine` is an independent, low-footprint offline engine that serializes entire transit graphs locally in SQLite, runs pure-code $A^*$ routing offline, buffers local BLE vicinity measurements in a store-and-forward outbox, and opportunistically flushes all buffered reports the split second a cellular heartbeat is detected.

---

## 📦 How to Push as a Separate GitHub Repository

This package is completely decoupled and self-contained in `packages/deadzone_engine` with its own `pubspec.yaml`, test suite, and models.

To push it as an independent repository on GitHub:

```bash
# Option A: Initialize a fresh Git repository inside the package folder
cd packages/deadzone_engine
git init
git add .
git commit -m "feat: initial commit of deadzone_engine package"
git remote add origin https://github.com/YOUR_USERNAME/deadzone_engine.git
git branch -M main
git push -u origin main
```

```bash
# Option B: Extract via git subtree from the root repository
git subtree push --prefix=packages/deadzone_engine https://github.com/YOUR_USERNAME/deadzone_engine.git main
```

---

## 🤝 Integration Contracts for Teammates

### 1. For Teammate 1 (BLE Device Vicinity & Congestion System)

When your BLE scanner counts nearby devices and computes the vicinity crowding factor:

```dart
import 'package:deadzone_engine/deadzone_engine.dart';

// Ingest crowd score (0 to 100):
// 0-25: Low, 26-60: Moderate, 61-85: Heavy, 86-100: Severe Rush
engine.recordCongestion(
  stationId: 'delhi_rajiv_chowk',
  score: 78, // 0 to 100
  platformOrLine: 'Platform 1 (Yellow Line towards Samaypur Badli)',
);

// If the passenger is underground in a deadzone, this reading is:
// 1. Instantly saved into the local SQLite store-and-forward outbox
// 2. Optimistically cached so the passenger immediately sees their own platform's crowd score
// 3. Held safely until cellular signal returns
```

### 2. Reading Station Congestion (45-Minute TTL)

```dart
final snapshot = engine.getStationCongestion('delhi_rajiv_chowk');

if (snapshot != null) {
  print('Congestion: ${snapshot.score}% (${snapshot.band.label})');
  print('Color: ${snapshot.band.colorHex}');
} else {
  print('No active report (older than 45-minute timeout TTL)');
}
```

### 3. Opportunistic Heartbeat Delta-Sync

When the passenger surfaces or the train reaches an above-ground/elevated station:

```dart
// Hooked automatically to OS network state or triggered manually:
engine.triggerCellularHeartbeat(note: 'Surfaced at elevated station');

// Listens to sync result:
engine.onCongestionSyncComplete.listen((result) {
  print('Synced: ${result.message} (Flushed ${result.flushedCount} reports)');
});
```

---

## 🧭 Offline Graph Traversal (A* & Dijkstra)

Calculate routes completely offline in pure Dart (< 2 milliseconds):

```dart
final route = engine.findRoute(
  originStationId: 'delhi_samaypur_badli',
  destinationStationId: 'delhi_noida_elec_city',
  preference: RoutingPreference.fastestTime, // or leastTransfers
);

print(route.summary); 
// Output: Yellow Line ➔ Blue Line (34 mins, 1 transfer at Rajiv Chowk)

print('Deadzone stations along route: ${route.deadzoneStations.map((s) => s.name)}');
// Output: [Chawri Bazar, Rajiv Chowk]
```

---

## 🧪 Automated Testing

Run the test suite directly from CLI:

```bash
cd packages/deadzone_engine
dart test
dart analyze
```
