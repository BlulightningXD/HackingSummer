# APK data and startup notes

The archived timetable is prebuilt into `data/schedule-cache/`. The app reads the small station list on startup and loads only the selected station's timetable. This avoids parsing the 6 MB GTFS `stop_times.txt` file each time the app launches.

For an Android wrapper such as Capacitor, include the whole `data/schedule-cache/` directory in the app's packaged web assets. The timetable screen first uses the lightweight local API when available, and falls back to those bundled JSON files. It also remembers the station list and recently opened station boards on the device, so those schedules remain available offline.

If the GTFS source is replaced, rebuild the bundle once before creating the APK:

```powershell
node .\build-schedule-cache.js
```

The basemap, geocoding and road directions still use online services. This timetable optimization does not make the map itself available offline. The schedule remains a historical 10 Aug 2023 snapshot and is not live train tracking.
