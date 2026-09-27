# Disha 🚇

**Disha** is a smart city navigation and real-time crowdsourced tracking application built for modern transit systems (initially targeted at the Delhi Metro). 

Disha goes beyond basic navigation by introducing a privacy-preserving crowd-density scanner, offline-first underground routing, and real-time community hazard reporting—all wrapped in a stunning, highly accessible user interface.

## 🌟 Key Features

* **Smart City Navigation:** Plan routes across the city using pedestrian, driving (via OSRM APIs), and custom Metro transit graphs. 
* **Underground Offline Routing (`DeadzoneEngine`):** Navigating the metro means losing cell service. Disha downloads the metro graph to a local SQLite database, allowing you to calculate complex routes and ETAs deep underground.
* **Passive Crowd Scanning (BLE):** Instead of relying on manual user input, Disha uses a privacy-first Bluetooth Low Energy (BLE) scanner to count nearby active Bluetooth signals (headphones, watches, phones) to estimate station and train congestion in real-time.
* **Real-time Hazard Reporting:** Tap a button to report delays, flooding, or obstacles. The map updates instantly for every user in the city via Firebase Cloud Firestore.
* **Community Lost & Found:** A real-time, photo-supported board for items lost or found within the transit network.
* **Premium Glassmorphic UI:** A gorgeous Bento-grid dashboard with dynamic blur effects. Includes a **Low Performance Mode** to boost framerates and save battery on older devices by gracefully falling back from blurs to solid colors.
* **Persistent Authentication:** Supports instant Dev Sandbox logins and Google OAuth. Sessions securely persist across app restarts using local `SharedPreferences`.

## 🛠️ Technology Stack

* **Frontend Framework:** Flutter (Dart)
* **Backend Database (Real-time):** Firebase Cloud Firestore
* **Local Database (Offline Routing):** SQLite (`sqlite3`)
* **Local Storage (Session):** `shared_preferences`
* **Maps & Geographic Data:** `flutter_map`, OpenStreetMap, OSRM, `geolocator`
* **Hardware Integrations:** `flutter_blue_plus` (BLE Scanning)

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (`>= 3.13.4`)
* Android Studio / Xcode for emulators
* A physical device is recommended to test the Bluetooth Low Energy (BLE) crowd scanning functionality.

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/BlulightningXD/HackingSummer.git
   cd HackingSummer
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup:**
   Ensure your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are properly placed in their respective directories if you plan on connecting to your own Firebase project.

4. **Run the app:**
   ```bash
   flutter run
   ```

## 🧠 Architecture Overview
* `lib/deadzone_engine.dart`: The core of the offline graph routing logic. It interfaces with SQLite to calculate paths using Dijkstra's algorithm.
* `lib/services/ble_crowd_scanner.dart`: The passive, privacy-preserving Bluetooth signal counter.
* `lib/auth_handler.dart`: Manages Google OAuth and Dev Sandbox sessions.
* `lib/home_map_screen.dart`: The primary controller for map rendering, live train simulation, and route drawing.

## 🎨 Theming & Accessibility
Disha strictly adheres to an accessible design philosophy. It supports:
* System-wide Dark and Light mode.
* High Contrast Mode for improved text legibility across complex maps.
* Performance Mode to reduce GPU strain.

---
*Built with ❤️ for a smarter, safer, and more connected commute.*
