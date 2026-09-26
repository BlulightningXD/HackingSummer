# 🚇 Disha: SafeRoute & Hazard Engine

**Forged by Team WatchDogs for Hacking Summer**

Metro One is a mobile-first, crowdsourced navigation and hazard-reporting application designed for urban commuters. This project shatters reliance on paid mapping services by utilizing an entirely open-source, community-driven spatial awareness system with a sleek, dark-themed UI.

## 🌟 Core Manifestations (Features)

* **The Obsidian Map (Open-Source Cartography):** A custom, deep-dark themed map powered by `flutter_map` and OpenStreetMap. Completely free from API key restrictions, utilizing a mathematical color matrix inversion to achieve a premium, distraction-free aesthetic.
* **Live Spatial Tracking:** Real-time GPS positioning using `geolocator` to seamlessly anchor the commuter upon the digital canvas.
* **OSRM Dynamic Routing:** Integrated pathfinding via the Open Source Routing Machine. Users can tap the map or search destinations to instantly draw precise navigation polylines for driving, cycling, or walking.
* **Community Hazard System (The Feedback Loop):**
  * **Instant Reporting:** Commuters can long-press the map to inscribe spatial hazards (e.g., potholes, flooding, accessibility issues) directly into the database, accompanied by native heavy haptic feedback.
  * **Democratic Verification:** A sleek bottom-sheet interface allows the community to upvote ("Still There") or downvote ("Resolved") hazards. Markers dynamically update their status or banish themselves entirely based on their reliability score.
* **Nominatim Search Integration:** Seamless location querying allowing users to find specific destinations and instantly calculate the safest route.
* **Unified Dashboard Nexus:** A central hub architecture designed to easily merge this mapping realm with other transit modules built by the team.

## 🛠️ The Technical Foundation

* **Frontend Framework:** Flutter (Dart)
* **Map & Navigation Libraries:** `flutter_map`, `latlong2`, OSRM (Routing), Nominatim (Search), `geolocator`
* **Backend API:** FastAPI (Python)
* **Spatial Database:** PostgreSQL coupled with PostGIS

## 🚀 Awakening the Artifact Locally

### 1. The Backend Realm (`saferoute_backend`)
1. Navigate into the backend directory.
2. Ensure your Python environment is active and requirements are installed.
3. Awaken the FastAPI server, exposing it to your local network:
   ```bash
   fastapi dev main.py --host 0.0.0.0
   ```

### 2. The Frontend Realm (`metro_one_app`)
1. Ensure your physical mobile device is connected via USB with Debugging enabled, or launch a virtual emulator.
2. Open `lib/complaints_map_screen.dart` and update the `apiUrl`, `postUrl`, and `voteUrl` IP addresses to match your machine's current local Wi-Fi IP.
3. Fetch the required Flutter dependencies:
   ```bash
   flutter pub get
   ```
4. Compile and launch the application:
   ```bash
   flutter run
   ```

## 🤝 Contribution
This repository contains both the Flutter application and the FastAPI backend. Contributors should create distinct branches for their respective modules (e.g., `feature/train-timing`) and merge them into the central `DashboardScreen` via Pull Requests.
