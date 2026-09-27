# Live Navigator for Android

This is the Kotlin Android host for the Live Navigator map. The map UI runs from the app's bundled web assets; Android provides the app lifecycle, secure local asset origin, and native runtime GPS permission. The historical Delhi Metro timetable is bundled, so it does not need the Node schedule server in the APK.

## Build

Open this folder in Android Studio and let it install the Android SDK packages, or build from a Windows terminal after installing Android SDK Platform 35 and Build Tools 35.0.0:

```powershell
.\gradlew.bat assembleDebug
```

The debug APK is written to `app/build/outputs/apk/debug/app-debug.apk`.

## Map and data behavior

- The metro timetable and 262 station entries are bundled locally and work without the schedule API.
- GPS prompts for Android location access and updates the blue position marker.
- Map tiles, destination search, and road directions still require an internet connection.
- Timetables are an archived 10 Aug 2023 schedule snapshot, not live train positions.
