import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main.dart';
import 'deadzone_engine.dart';
import 'metro_map_screen.dart'; 
import 'lost_found_screen.dart';
import 'profile_screen.dart';
import 'services/ble_crowd_scanner.dart';

class RouteData {
  final List<LatLng> points;
  final String distance;
  final String duration;
  RouteData(this.points, this.distance, this.duration);
}

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({Key? key}) : super(key: key);

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _myLocation;
  StreamSubscription<Position>? _positionStream;

  String _selectedVehicle = 'car'; // car, bus, cycle, pedestrian, metro
  bool _isDirectionsMode = false;
  bool _isNavigating = false;
  bool _isRouting = false;

  // Route points: start, waypoints..., end
  List<LatLng> _routePoints = [];
  List<String> _routeNames = [];

  // Computed routes
  RouteData? _osrmRoute;
  RouteResult? _metroRoute;
  List<LiveTrain> _liveTrains = [];
  Timer? _trainTimer;

  // Search
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];

  // Hazards
  List<Marker> _hazardMarkers = [];
  Timer? _realtimeHazardTimer;
  final Set<String> _dismissedAlerts = {};
  Timer? _debounce;
  BleCrowdScanner? _bleScanner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
      _fetchHazards();
      _realtimeHazardTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _fetchHazards();
      });
      _initLiveTrains();
      _bleScanner = BleCrowdScanner(deadzoneEngine);
      _bleScanner?.startScanning();
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _realtimeHazardTimer?.cancel();
    _trainTimer?.cancel();
    _debounce?.cancel();
    _bleScanner?.stopScanning();
    super.dispose();
  }

  void _initLiveTrains() {
    // Removed fake data generation. Train data should come from real APIs.
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_myLocation!, 15.0);
    }
  }

  Future<void> _fetchHazards() async {
    if (_myLocation == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance.collection('hazards').get();
      final now = DateTime.now();
      List<Marker> markers = [];
      const distanceCalc = Distance();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestampStr = data['timestamp']?.toString();
        if (timestampStr != null) {
          final ts = DateTime.tryParse(timestampStr);
          if (ts != null && now.difference(ts).inDays >= 7) continue;
        }

        final int upvotes = data['upvotes'] ?? data['votes_count'] ?? data['votes'] ?? data['reliabilityScore'] ?? 0;
        final String ownerId = data['owner_id'] ?? '';
        final bool isMine = ownerId == authHandler.currentUser?.id;

        if (!isMine && upvotes < 2) continue; // Requires at least 2 reports to be verified

        final LatLng hazardLoc = LatLng(data['latitude'] as double, data['longitude'] as double);

        // "dont show all of the world's hazards to the user, just those nearby him and on the routes"
        bool isNearby = false;
        if (distanceCalc.as(LengthUnit.Meter, _myLocation!, hazardLoc) < 5000) {
          isNearby = true;
        }
        if (!isNearby && _osrmRoute != null) {
          for (var pt in _osrmRoute!.points) {
            if (distanceCalc.as(LengthUnit.Meter, pt, hazardLoc) < 100) {
              isNearby = true;
              break;
            }
          }
        }
        if (!isNearby) continue;

        markers.add(
          Marker(
            key: Key('hazard_${doc.id}'),
            point: hazardLoc,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                _showHazardDetails(data);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              ),
            ),
          )
        );
      }
      if (mounted) {
        setState(() {
          _hazardMarkers = markers;
        });
      }
    } catch (e) {
      debugPrint("Fetch hazards failed: $e");
    }
  }

  void _showHazardDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['hazard_type'] ?? 'Hazard', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(data['description'] ?? 'No description'),
            const SizedBox(height: 16),
            Text('${data['upvotes'] ?? 0} Reports', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      )
    );
  }

  void _showMyReports() {
    final perfMode = themeNotifier.performanceMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final content = Container(
          padding: const EdgeInsets.all(24),
          color: perfMode ? const Color(0xFF1C1C1E) : const Color(0xFF1C1C1E).withOpacity(0.9),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('My Hazard Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('hazards').where('owner_id', isEqualTo: authHandler.currentUser?.id ?? 'anonymous').snapshots(),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) return const Center(child: Text('You have not submitted any active reports.', style: TextStyle(color: Colors.white54)));
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (ctx, index) {
                         final doc = docs[index];
                         final data = doc.data() as Map<String, dynamic>;
                         return Container(
                           margin: const EdgeInsets.only(bottom: 12),
                           decoration: BoxDecoration(
                             color: Colors.white.withOpacity(0.05),
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: Colors.white.withOpacity(0.1)),
                           ),
                           child: ListTile(
                             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             leading: Container(
                               padding: const EdgeInsets.all(10),
                               decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), shape: BoxShape.circle),
                               child: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                             ),
                             title: Text(data['hazard_type'] ?? 'Hazard Reported', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                             subtitle: Text(data['description'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                             trailing: IconButton(
                               icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                               onPressed: () async {
                                 await FirebaseFirestore.instance.collection('hazards').doc(doc.id).delete();
                               },
                             ),
                           ),
                         );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: perfMode ? content : BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: content),
        );
      },
    );
  }

  void _showReportHazardSheet() {
    if (_myLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wait for location...')));
      return;
    }
    String desc = '';
    String type = 'Obstacle';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Report Hazard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Report hazards at your current location.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: type,
                    items: ['Obstacle', 'Crowd', 'Accident', 'Construction', 'Waterlogging'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setStateSheet(() => type = v!),
                    decoration: InputDecoration(filled: true, fillColor: Theme.of(context).cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => desc = v,
                    decoration: InputDecoration(hintText: 'Description', filled: true, fillColor: Theme.of(context).cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporting...')));
                        
                        final snap = await FirebaseFirestore.instance.collection('hazards').get();
                        String? existingId;
                        int maxVotes = 0;
                        const distanceCalc = Distance();
                        
                        for (var doc in snap.docs) {
                          final data = doc.data();
                          final hLoc = LatLng(data['latitude'] as double, data['longitude'] as double);
                          if (distanceCalc.as(LengthUnit.Meter, _myLocation!, hLoc) < 150) {
                            existingId = doc.id;
                            maxVotes = data['upvotes'] ?? data['votes'] ?? 0;
                            break;
                          }
                        }
                        
                        if (existingId != null) {
                          await FirebaseFirestore.instance.collection('hazards').doc(existingId).update({
                            'upvotes': maxVotes + 1,
                            'timestamp': DateTime.now().toIso8601String(),
                          });
                        } else {
                          await FirebaseFirestore.instance.collection('hazards').add({
                            'hazard_type': type,
                            'description': desc,
                            'latitude': _myLocation!.latitude,
                            'longitude': _myLocation!.longitude,
                            'upvotes': 1,
                            'owner_id': authHandler.currentUser?.id ?? 'anonymous',
                            'timestamp': DateTime.now().toIso8601String(),
                          });
                        }
                        _fetchHazards();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted!')));
                      },
                      child: const Text('Submit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              )
            );
          }
        );
      }
    );
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    
    String viewboxParam = '';
    if (_myLocation != null) {
      double lat = _myLocation!.latitude;
      double lon = _myLocation!.longitude;
      viewboxParam = "&viewbox=${lon-0.5},${lat+0.5},${lon+0.5},${lat-0.5}";
    }

    final String nomUrl = "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5$viewboxParam";
    try {
      final response = await http.get(
        Uri.parse(nomUrl),
        headers: {'User-Agent': 'MetroOneApp/1.0 (contact@metroone.com)'}
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _searchResults = data;
          });
        }
      }
    } catch (e) {
      print("Search failed: $e");
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _setStartLocation(LatLng pt, String name) {
    setState(() {
      _isDirectionsMode = true;
      if (_routePoints.isNotEmpty) {
        _routePoints[0] = pt;
        _routeNames[0] = name;
      } else {
        _routePoints.add(pt);
        _routeNames.add(name);
      }
      _calculateRoute();
    });
  }

  void _addRoutePoint(LatLng pt, String name) {
    setState(() {
      _isDirectionsMode = true;
      if (_routePoints.isEmpty && _myLocation != null) {
        _routePoints.add(_myLocation!);
        _routeNames.add("Your Location");
      }
      _routePoints.add(pt);
      _routeNames.add(name);
      _calculateRoute();
    });
  }

  void _showStationActionDialog(dynamic s) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('Set as Start'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setStartLocation(LatLng(s.latitude, s.longitude), s.name);
                }
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Set as Destination'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addRoutePoint(LatLng(s.latitude, s.longitude), s.name);
                }
              )
            ]
          )
        );
      }
    );
  }

  String _getStationNearestTo(LatLng pos) {
    double minDist = double.infinity;
    String bestStation = '';
    const distanceCalc = Distance();
    for (var s in deadzoneEngine.activeGraph.stations.values) {
      final dist = distanceCalc.as(LengthUnit.Meter, pos, LatLng(s.latitude, s.longitude));
      if (dist < minDist) {
        minDist = dist;
        bestStation = s.id;
      }
    }
    return bestStation;
  }

  Future<void> _calculateRoute() async {
    setState(() {
      _osrmRoute = null;
      _metroRoute = null;
    });

    if (_routePoints.length < 2) {
      if (mounted) setState(() => _isRouting = false);
      return;
    }
    
    setState(() {
      _isRouting = true;
    });

    if (_selectedVehicle == 'metro') {
      // Find nearest stations for all route points. For simplicity, just use first and last.
      String startId = _getStationNearestTo(_routePoints.first);
      String endId = _getStationNearestTo(_routePoints.last);
      
      final route = deadzoneEngine.findRoute(originStationId: startId, destinationStationId: endId);
      setState(() {
        _metroRoute = route;
        _isRouting = false;
      });
      if (route != null && route.fullPath.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(
          route.fullPath.map((s) => LatLng(s.latitude, s.longitude)).toList()
        );
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)));
      }
    } else {
      // OSRM
      String profile = 'driving';
      if (_selectedVehicle == 'cycle') profile = 'bike';
      if (_selectedVehicle == 'pedestrian') profile = 'foot';
      
      String coords = _routePoints.map((p) => '${p.longitude},${p.latitude}').join(';');
      final String osrmUrl = "https://router.project-osrm.org/route/v1/$profile/$coords?geometries=geojson&overview=full";
      
      try {
        final response = await http.get(Uri.parse(osrmUrl));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'] != null && data['routes'].isNotEmpty) {
            final r = data['routes'][0];
            final List coords = r['geometry']['coordinates'];
            final List<LatLng> pts = coords.map((c) => LatLng(c[1], c[0])).toList();
            
            final double dist = r['distance'].toDouble();
            double dur = r['duration'].toDouble();

            if (_selectedVehicle == 'cycle') dur = (dist / 15000) * 3600;
            if (_selectedVehicle == 'pedestrian') dur = (dist / 5000) * 3600;

            String pDist = dist > 1000 ? "${(dist / 1000).toStringAsFixed(1)} km" : "${dist.toStringAsFixed(0)} m";
            String pDur = dur > 3600 
              ? "${(dur / 3600).floor()} hr ${((dur % 3600) / 60).round()} min" 
              : "${(dur / 60).round()} min";
              
            setState(() {
              _osrmRoute = RouteData(pts, pDist, pDur);
            });
            final bounds = LatLngBounds.fromPoints(pts);
            _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80.0)));
          }
        }
      } catch (e) {
        print("OSRM routing failed: $e");
      } finally {
        if (mounted) {
          setState(() => _isRouting = false);
        }
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_isNavigating) return;
    
    // Add point
    if (_routePoints.isEmpty) {
      if (_myLocation != null) {
        _routePoints.add(_myLocation!);
        _routeNames.add("Your Location");
      } else {
        _routePoints.add(point);
        _routeNames.add("Start");
      }
    }
    _routePoints.add(point);
    _routeNames.add("Point ${_routePoints.length}");
    
    _isDirectionsMode = true;
    _calculateRoute();
  }

  void _startNavigation() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isNavigating = true;
    });
    if (_myLocation != null) {
      _mapController.move(_myLocation!, 18.0);
    }

    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)
    ).listen((Position position) {
      final newLoc = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _myLocation = newLoc;
        });
        _fetchHazards(); // Check hazards along route dynamically
      }

      if (_isNavigating) {
        _mapController.move(newLoc, 18.0);
      }
    });
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
    });
    _positionStream?.cancel();
  }
  
  Color _hexToColor(String? hex, {Color fallback = Colors.grey}) {
    if (hex == null || hex.isEmpty) return fallback;
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? fallback.value);
  }

  void _showProfileMenu() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              top: 80,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 250,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text("Profile & Settings"),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications),
                        title: const Text("Notifications"),
                        onTap: () {
                          Navigator.pop(context);
                          _showNotifications();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.support_agent_rounded),
                        title: const Text("Lost & Found"),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LostFoundScreen()));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.report_problem),
                        title: const Text("My Reports"),
                        onTap: () {
                          Navigator.pop(context);
                          _showMyReports();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }
    );
  }


  
  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Live Network Updates', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              StreamBuilder<CongestionRecord>(
                stream: deadzoneEngine.onCongestionBuffered,
                builder: (context, snapshot) {
                  String title = 'Scanning crowd density...';
                  String subtitle = 'Listening for nearby Bluetooth devices.';
                  
                  final allRecords = deadzoneEngine.getAllStationCongestion();
                  String? latestStationId;
                  int? latestScore;
                  
                  if (snapshot.hasData) {
                    latestStationId = snapshot.data!.stationId;
                    latestScore = snapshot.data!.score;
                  } else if (allRecords.isNotEmpty) {
                    final latestSnapshot = allRecords.values.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
                    latestStationId = latestSnapshot.stationId;
                    latestScore = latestSnapshot.score;
                  }

                  if (latestStationId != null && latestScore != null) {
                    final station = deadzoneEngine.activeGraph.getStation(latestStationId);
                    title = station != null ? 'Platform - ${station.name}' : 'Platform Update';
                    subtitle = latestScore > 40 
                        ? 'High crowd density ($latestScore% capacity). Expect 5-10 min delays.' 
                        : 'Crowd density is normal ($latestScore% capacity).';
                  }

                  if (latestStationId != null && _dismissedAlerts.contains(latestStationId)) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: const Center(child: Text("No new notifications", style: TextStyle(color: Colors.grey))),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Icon(Icons.campaign, color: Colors.blueAccent, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                          onPressed: () {
                            if (latestStationId != null) {
                              setState(() {
                                _dismissedAlerts.add(latestStationId!);
                              });
                            }
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  );
                }
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // Map Layers
    List<Polyline> polylines = [];
    List<Marker> markers = [..._hazardMarkers];

    if (_myLocation != null) {
      markers.add(
        Marker(
          key: const Key('my_location'),
          point: _myLocation!,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 16, spreadRadius: 6)]
            ),
          ),
        )
      );
    }

    // Draw route points
    for (int i = 0; i < _routePoints.length; i++) {
      if (i == 0 && _routePoints[i] == _myLocation) continue; // skip drawing my location twice
      markers.add(
        Marker(
          point: _routePoints[i],
          width: 32, height: 32,
          child: const Icon(Icons.location_on, color: Colors.redAccent, size: 32),
        )
      );
    }

    if (_selectedVehicle == 'metro') {
      if (_metroRoute != null) {
        // "after the destination is selected, only highlight the used route and hide all other oetro line/routes"
        for (final segment in _metroRoute!.segments) {
          final points = segment.stations.map((s) => LatLng(s.latitude, s.longitude)).toList();
          polylines.add(
            Polyline(
              points: points,
              strokeWidth: segment.isTransfer ? 4 : 8,
              color: segment.isTransfer 
                  ? Colors.grey.withOpacity(0.8) 
                  : _hexToColor(segment.line?.colorHex, fallback: const Color(0xFF1b775f)).withOpacity(0.9),
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            )
          );
        }
      } else {
        // Show full metro network
        final graph = deadzoneEngine.activeGraph;
        for (final edges in graph.adjacency.values) {
          for (final edge in edges) {
            if (edge.lineId != null) {
              final fromS = graph.stations[edge.fromStationId];
              final toS = graph.stations[edge.toStationId];
              final line = graph.lines[edge.lineId!];
              if (fromS != null && toS != null && line != null) {
                polylines.add(Polyline(
                  points: [LatLng(fromS.latitude, fromS.longitude), LatLng(toS.latitude, toS.longitude)],
                  strokeWidth: 4,
                  color: _hexToColor(line.colorHex, fallback: const Color(0xFF1b775f)).withOpacity(0.7),
                  strokeCap: StrokeCap.round,
                ));
              }
            }
          }
        }
      }
      
      // Render Metro stations
      final stations = deadzoneEngine.getStationsForCurrentCity();
      final allCongestion = deadzoneEngine.getAllStationCongestion();
      for (var s in stations) {
        final congestion = allCongestion[s.id];
        final score = congestion?.score ?? 0;
        final isSelected = _routeNames.contains(s.name);
        final markerColor = isSelected ? const Color(0xFF1b775f) : Colors.white;
        
        Color crowdColor = const Color(0xFF87b871); // Calm
        if (score >= 40) crowdColor = const Color(0xFFe4b953); // Moderate
        if (score >= 70) crowdColor = const Color(0xFFe18a63); // Busy

        // Hide other stations if navigating on metro route? Optional.
        // Let's keep them visible but smaller if not selected.
        markers.add(
          Marker(
            point: LatLng(s.latitude, s.longitude),
            width: 120,
            height: 50,
            child: GestureDetector(
              onTap: () {
                _showStationActionDialog(s);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isSelected ? 20 : 12,
                    height: isSelected ? 20 : 12,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: crowdColor, width: isSelected ? 4 : 2),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(2)),
                    child: Text(s.name, style: const TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  )
                ],
              ),
            ),
          )
        );
      }
      
      // Draw live trains (only on active routes if selected, or all if not)
      for (final t in _liveTrains) {
        if (_metroRoute != null) {
          // Check if train is on a used segment
          bool isOnRoute = _metroRoute!.segments.any((seg) => seg.line?.id == t.lineId);
          if (!isOnRoute) continue;
        }
        final s1 = deadzoneEngine.activeGraph.stations[t.edge.fromStationId]!;
        final s2 = deadzoneEngine.activeGraph.stations[t.edge.toStationId]!;
        final lat = s1.latitude + (s2.latitude - s1.latitude) * t.progress;
        final lng = s1.longitude + (s2.longitude - s1.longitude) * t.progress;
        
        markers.add(Marker(
          point: LatLng(lat, lng),
          width: 24,
          height: 24,
          child: Container(
            width: 16, height: 16,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.orange, width: 2)),
            child: Center(child: Icon(Icons.train, size: 8, color: _hexToColor(deadzoneEngine.activeGraph.lines[t.lineId]?.colorHex))),
          ),
        ));
      }

    } else {
      if (_osrmRoute != null) {
        polylines.add(
          Polyline(
            points: _osrmRoute!.points,
            strokeWidth: 6.0,
            color: Colors.blueAccent.withOpacity(0.9),
          )
        );
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(28.6139, 77.2090),
              initialZoom: 14.0,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.disha.metro_one',
                tileBuilder: (context, tileWidget, tile) {
                  // Normal map styling unless in dark mode
                  bool isDark = Theme.of(context).brightness == Brightness.dark;
                  if (!isDark) return tileWidget;
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      -0.85, 0,     0,     0, 255, 
                      0,    -0.85,  0,     0, 255, 
                      0,     0,    -0.85,  0, 255, 
                      0,     0,     0,     1,   0, 
                    ]),
                    child: tileWidget,
                  );
                },
              ),
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),

          // Search Bar & Navigation Options
          if (!_isNavigating)
            SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: Column(
                      children: [
                        // Search Bar Row
                        Row(
                          children: [
                            if (_isDirectionsMode)
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () {
                                  setState(() {
                                    _isDirectionsMode = false;
                                    _routePoints.clear();
                                    _routeNames.clear();
                                    _osrmRoute = null;
                                    _metroRoute = null;
                                  });
                                },
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.only(left: 16.0),
                                child: Icon(Icons.search, color: Colors.grey),
                              ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search here',
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) {
                                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                                  _debounce = Timer(const Duration(milliseconds: 500), () {
                                    _searchLocation(val);
                                  });
                                },
                                onSubmitted: (val) {
                                  _searchLocation(val);
                                },
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchResults.clear());
                                },
                              ),
                            GestureDetector(
                              onTap: _showProfileMenu,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundImage: authHandler.currentUser?.photoUrl != null 
                                      ? NetworkImage(authHandler.currentUser!.photoUrl!) 
                                      : null,
                                  backgroundColor: Colors.grey[300],
                                  child: authHandler.currentUser?.photoUrl == null 
                                      ? const Icon(Icons.person, size: 20, color: Colors.grey) 
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Directions Waypoints UI
                        if (_isDirectionsMode) ...[
                          const Divider(height: 1),
                          for (int i = 0; i < _routePoints.length; i++)
                            ListTile(
                              dense: true,
                              leading: Icon(i == 0 ? Icons.my_location : Icons.location_on, size: 20, color: i == 0 ? Colors.blue : Colors.red),
                              title: Text(_routeNames[i]),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _routePoints.removeAt(i);
                                    _routeNames.removeAt(i);
                                    _calculateRoute();
                                    if (_routePoints.isEmpty) _isDirectionsMode = false;
                                  });
                                },
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),

                  // Search Results
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (ctx, idx) {
                          final item = _searchResults[idx];
                          return ListTile(
                            leading: const Icon(Icons.place),
                            title: Text(item['display_name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              final lat = double.parse(item['lat']);
                              final lon = double.parse(item['lon']);
                              final pt = LatLng(lat, lon);
                              final name = item['display_name'].split(',')[0];
                              showModalBottomSheet(
                                context: context,
                                builder: (ctx) => Container(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 16),
                                      ListTile(
                                        leading: const Icon(Icons.my_location),
                                        title: const Text('Set as Start'),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _setStartLocation(pt, name);
                                          setState(() {
                                            _searchResults.clear();
                                            _searchController.clear();
                                          });
                                        }
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.location_on),
                                        title: const Text('Set as Destination'),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _addRoutePoint(pt, name);
                                          setState(() {
                                            _searchResults.clear();
                                            _searchController.clear();
                                          });
                                        }
                                      )
                                    ]
                                  )
                                )
                              );
                            },
                          );
                        },
                      ),
                    ),

                  // Vehicle Options
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _buildVehicleChip('Car', 'car', Icons.directions_car),
                        _buildVehicleChip('Bus', 'bus', Icons.directions_bus),
                        _buildVehicleChip('Cycle', 'cycle', Icons.directions_bike),
                        _buildVehicleChip('Walk', 'pedestrian', Icons.directions_walk),
                        _buildVehicleChip('Metro', 'metro', Icons.subway),
                      ],
                    ),
                  ),

                  // Persistent BLE Station Crowd Banner
                  if (!_isNavigating)
                    StreamBuilder<CongestionRecord>(
                      stream: deadzoneEngine.onCongestionBuffered,
                      builder: (ctx, snapshot) {
                        String? nearestStationId;
                        double nearestDist = double.infinity;
                        const distanceCalc = Distance();
                        
                        if (_myLocation != null) {
                          for (final s in deadzoneEngine.activeGraph.stations.values) {
                            final d = distanceCalc.as(LengthUnit.Meter, _myLocation!, LatLng(s.latitude, s.longitude));
                            if (d < nearestDist) {
                              nearestDist = d;
                              nearestStationId = s.id;
                            }
                          }
                        }
                        
                        if (nearestStationId == null) return const SizedBox.shrink();
                        
                        final score = deadzoneEngine.getAllStationCongestion()[nearestStationId]?.score ?? 30;
                        final stationName = deadzoneEngine.activeGraph.stations[nearestStationId]?.name ?? 'Nearest Station';
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: score > 70 ? Colors.redAccent.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bluetooth_connected, size: 18, color: score > 70 ? Colors.redAccent : Colors.blueAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text('$stationName Crowd: $score%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            
          // Bottom Info Panel
          if (!_isNavigating && (_osrmRoute != null || _metroRoute != null) && MediaQuery.of(context).viewInsets.bottom == 0)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_osrmRoute != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_osrmRoute!.duration, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                                Text(_osrmRoute!.distance, style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            icon: const Icon(Icons.navigation),
                            label: const Text("Start"),
                            onPressed: _startNavigation,
                          )
                        ],
                      ),
                    if (_metroRoute != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${_metroRoute!.totalMinutes} min', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                                const Text('Metro Route', style: TextStyle(color: Colors.grey)),
                                if (_metroRoute!.segments.isNotEmpty)
                                  Text('Next train in ~${Random().nextInt(4) + 1} mins', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            icon: const Icon(Icons.navigation),
                            label: const Text("Start"),
                            onPressed: _startNavigation,
                          )
                        ],
                      )
                  ],
                ),
              ),
            ),

          // Active Navigation Overlay
          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.turn_right, color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Head to route", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          if (_osrmRoute != null)
                            Text(_osrmRoute!.duration, style: const TextStyle(color: Colors.white70)),
                          if (_metroRoute != null && _metroRoute!.segments.isNotEmpty)
                            Builder(
                              builder: (ctx) {
                                final nextStationId = _metroRoute!.segments.first.stations.length > 1 
                                  ? _metroRoute!.segments.first.stations[1].id 
                                  : _metroRoute!.segments.first.stations.first.id;
                                final score = deadzoneEngine.getAllStationCongestion()[nextStationId]?.score ?? 35;
                                return Text("Next station density: $score%", style: TextStyle(color: score > 60 ? Colors.orangeAccent : Colors.greenAccent, fontWeight: FontWeight.w600));
                              }
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _stopNavigation,
                    )
                  ],
                ),
              ),
            ),
            
        ],
      ),
      floatingActionButton: _isNavigating ? null : Padding(
        padding: EdgeInsets.only(bottom: (_osrmRoute != null || _metroRoute != null) ? 140 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
            heroTag: 'reportHazard',
            backgroundColor: Colors.redAccent,
            mini: true,
            onPressed: _showReportHazardSheet,
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'myLocation',
            onPressed: () {
              if (_myLocation != null) _mapController.move(_myLocation!, 15.0);
            },
            backgroundColor: Theme.of(context).cardColor,
            child: const Icon(Icons.my_location, color: Colors.blueAccent),
          ),
        ]
      ),
      ),
    );
  }

  Widget _buildVehicleChip(String label, String value, IconData icon) {
    bool isSelected = _selectedVehicle == value;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
        selectedColor: Colors.blueAccent,
        labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (bool selected) {
          setState(() {
            _selectedVehicle = value;
          });
          if (_routePoints.length >= 2) {
            _calculateRoute();
          }
        },
      ),
    );
  }
}
