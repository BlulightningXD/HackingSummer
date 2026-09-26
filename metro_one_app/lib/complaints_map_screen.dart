import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class RouteData {
  final List<LatLng> points;
  final String distance;
  final String duration;
  RouteData(this.points, this.distance, this.duration);
}

class ComplaintsMapScreen extends StatefulWidget {
  const ComplaintsMapScreen({Key? key}) : super(key: key);

  @override
  State<ComplaintsMapScreen> createState() => _ComplaintsMapScreenState();
}

class _ComplaintsMapScreenState extends State<ComplaintsMapScreen> {
  final MapController mapController = MapController();
  List<Marker> _markers = [];
  LatLng? _myLocation; 
  StreamSubscription<Position>? _positionStream;
  Timer? _realtimeHazardTimer;

  // Routing State
  RouteData? _primaryRoute;
  List<RouteData> _alternateRoutes = [];
  String _selectedVehicle = 'driving'; // driving, bike, foot
  LatLng? _currentDestination;
  bool _isNavigating = false;
  bool _isRouting = false;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];

  final LatLng _initialPosition = const LatLng(28.6200, 77.3800);
  final String apiUrl = "http://10.214.193.85:8000/api/complaints/area"; 
  final Set<int> _hiddenHurdles = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _findMyVessel();
      _fetchHurdlesInView();
      // Poll every 30 seconds for real-time hazard updates across the platform
      _realtimeHazardTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _fetchHurdlesInView();
      });
    });
  }

  @override
  void dispose() {
    _realtimeHazardTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _findMyVessel() async {
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
        _updateLocationMarker();
      });
    }
    
    if (!_isNavigating) {
      mapController.move(_myLocation!, 15.0); 
    }
  }

  void _updateLocationMarker() {
    _markers.removeWhere((m) => m.key == const Key('my_location'));
    if (_myLocation != null) {
      _markers.add(
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
              boxShadow: [
                BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 16, spreadRadius: 6),
              ]
            ),
          ),
        ),
      );
    }
  }

  void _startNavigation() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isNavigating = true;
    });
    if (_myLocation != null) {
      mapController.move(_myLocation!, 18.0);
    }

    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)
    ).listen((Position position) {
      final newLoc = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _myLocation = newLoc;
          _updateLocationMarker();
        });
      }

      if (_isNavigating && _primaryRoute != null && _currentDestination != null) {
        mapController.move(newLoc, 18.0);
        
        // Reroute if user deviates more than 50 meters from the primary path
        double minDistance = double.infinity;
        const distanceCalc = Distance();
        for (var pt in _primaryRoute!.points) {
          final dist = distanceCalc.as(LengthUnit.Meter, newLoc, pt);
          if (dist < minDistance) minDistance = dist;
        }
        
        if (minDistance > 50 && !_isRouting) {
          _calculateRoute(_currentDestination!, vehicle: _selectedVehicle);
        }
      }
    });
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
    });
    _positionStream?.cancel();
    if (_primaryRoute != null && _primaryRoute!.points.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(_primaryRoute!.points);
      mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80.0)));
    }
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
        headers: {'User-Agent': 'MetroOneApp/1.0 (Contact: user@metroone.app)'},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _searchResults = data;
            if (data.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No matching locations found.')),
              );
            }
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

  Future<void> _calculateRoute(LatLng destination, {String vehicle = 'driving'}) async {
    if (_myLocation == null) return;
    HapticFeedback.lightImpact();

    setState(() => _isRouting = true);

    final String profile = vehicle == 'driving' ? 'driving' : (vehicle == 'bike' ? 'bike' : 'foot');
    final String osrmUrl = "https://router.project-osrm.org/route/v1/$profile/${_myLocation!.longitude},${_myLocation!.latitude};${destination.longitude},${destination.latitude}?geometries=geojson&overview=full&alternatives=true";
    
    try {
      final response = await http.get(Uri.parse(osrmUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        
        RouteData? primary;
        List<RouteData> alts = [];

        for (int i = 0; i < routes.length; i++) {
          final r = routes[i];
          final List coords = r['geometry']['coordinates'];
          final List<LatLng> pts = coords.map((c) => LatLng(c[1], c[0])).toList();
          
          final double dist = r['distance'].toDouble();
          double dur = r['duration'].toDouble();

          // Enforce realistic speeds if OSRM defaults to car speeds for all profiles
          if (vehicle == 'bike') dur = (dist / 15000) * 3600; // ~15 km/h
          if (vehicle == 'foot') dur = (dist / 5000) * 3600;  // ~5 km/h

          String pDist = dist > 1000 ? "${(dist / 1000).toStringAsFixed(1)} km" : "${dist.toStringAsFixed(0)} m";
          String pDur = dur > 3600 
            ? "${(dur / 3600).floor()} hr ${((dur % 3600) / 60).round()} min" 
            : "${(dur / 60).round()} min";
            
          final rd = RouteData(pts, pDist, pDur);
          
          if (i == 0) {
            primary = rd;
          } else {
            alts.add(rd);
          }
        }
        
        if (mounted) {
          setState(() {
            _selectedVehicle = vehicle;
            _currentDestination = destination;
            _primaryRoute = primary;
            _alternateRoutes = alts;
            
            _markers.removeWhere((m) => m.key == const Key('destination'));
            _markers.add(
              Marker(
                key: const Key('destination'),
                point: destination,
                width: 44,
                height: 44,
                child: const Icon(Icons.location_on, color: Colors.redAccent, size: 44),
              )
            );
          });
        }

        if (!_isNavigating && primary != null && primary.points.isNotEmpty) {
          final bounds = LatLngBounds.fromPoints(primary.points);
          mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80.0)));
        }
      }
    } catch (e) {
      print("Routing realm severed: $e");
    } finally {
      if (mounted) {
        setState(() => _isRouting = false);
      }
    }
  }

  Future<void> _fetchHurdlesInView() async {
    final bounds = mapController.camera.visibleBounds;
    final response = await http.get(Uri.parse(
        '$apiUrl?min_lat=${bounds.southWest.latitude}&min_lng=${bounds.southWest.longitude}&max_lat=${bounds.northEast.latitude}&max_lng=${bounds.northEast.longitude}'
    ));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> hurdles = data['data'];

      if (mounted) {
        setState(() {
          _markers.removeWhere((m) => m.key != const Key('my_location') && m.key != const Key('destination'));
          
          _markers.addAll(hurdles.where((h) => !_hiddenHurdles.contains(h['id'])).map((hurdle) {
            final isVerified = (hurdle['reliabilityScore'] ?? 0) > 0;
            return Marker(
              key: Key('hurdle_${hurdle['id']}'),
              point: LatLng(hurdle['latitude'], hurdle['longitude']),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showHurdleDetails(hurdle as Map<String, dynamic>);
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: isVerified ? Colors.redAccent.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: isVerified ? Colors.redAccent : Colors.orangeAccent, width: 2),
                      ),
                      child: Icon(
                        isVerified ? Icons.error : Icons.warning_amber_rounded, 
                        color: isVerified ? Colors.redAccent : Colors.orangeAccent, 
                        size: 20
                      ),
                    ),
                  ],
                ),
              ),
            );
          }));
        });
      }
    }
  }

  void _onMapLongPress(TapPosition tapPosition, LatLng position) {
    if (_isNavigating) return;
    HapticFeedback.heavyImpact();
    _showAddHurdleDialog(position);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    FocusScope.of(context).unfocus();
    setState(() => _searchResults.clear());
    
    // Switch to alternate route if tapped near one
    if (!_isNavigating && _alternateRoutes.isNotEmpty && _primaryRoute != null) {
      const distance = Distance();
      int bestAltIndex = -1;
      double minAltDist = double.infinity;
      
      for (int i = 0; i < _alternateRoutes.length; i++) {
         for (var p in _alternateRoutes[i].points) {
           final d = distance.as(LengthUnit.Meter, point, p);
           if (d < minAltDist) { minAltDist = d; bestAltIndex = i; }
         }
      }
      
      double minPrimDist = double.infinity;
      for (var p in _primaryRoute!.points) {
           final d = distance.as(LengthUnit.Meter, point, p);
           if (d < minPrimDist) minPrimDist = d;
      }

      if (minAltDist < 100 && minAltDist < minPrimDist && bestAltIndex != -1) {
         HapticFeedback.mediumImpact();
         setState(() {
            final temp = _primaryRoute!;
            _primaryRoute = _alternateRoutes[bestAltIndex];
            _alternateRoutes[bestAltIndex] = temp;
         });
      }
    }
  }

  Widget _buildGlassFab({required IconData icon, required VoidCallback onPressed, required Color color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: const Color(0xFF1C1C1E).withOpacity(0.85),
          child: InkWell(
            onTap: onPressed,
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleOption(String type, IconData icon) {
    final isSelected = _selectedVehicle == type;
    return GestureDetector(
      onTap: () {
        if (_currentDestination != null && !isSelected) {
          _calculateRoute(_currentDestination!, vehicle: type);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.transparent),
        ),
        child: Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white54, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background fallback
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 14.0,
              onLongPress: _onMapLongPress,
              onTap: _onMapTap, 
              onMapEvent: (MapEvent event) {
                if (event is MapEventMoveEnd) {
                  _fetchHurdlesInView();
                }
              },
            ),
            children: [
              TileLayer(
                // Reverting to OpenStreetMap to prevent API Key blocks, but using a custom deep dark ColorFilter!
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.metro_one',
                tileBuilder: (context, tileWidget, tile) {
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
              PolylineLayer(
                polylines: [
                  for (final alt in _alternateRoutes)
                    Polyline(
                      points: alt.points,
                      strokeWidth: 4.0,
                      color: Colors.grey.withOpacity(0.4),
                    ),
                  if (_primaryRoute != null)
                    Polyline(
                      points: _primaryRoute!.points,
                      strokeWidth: 6.0,
                      color: Colors.blueAccent.withOpacity(0.9),
                    ),
                ],
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          
          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16, right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.9), // Emerald green
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 6))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.turn_right, color: Colors.white, size: 44),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Follow Route", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(_primaryRoute?.distance ?? '', style: const TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            padding: const EdgeInsets.all(12)
                          ),
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _stopNavigation,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (!_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E).withOpacity(0.85),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.white54, size: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                decoration: const InputDecoration(
                                  hintText: 'Search destination...',
                                  hintStyle: TextStyle(color: Colors.white38),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (value) {
                                  FocusScope.of(context).unfocus();
                                  _searchLocation(value);
                                },
                              ),
                            ),
                            if (_isSearching)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                                ),
                              ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchResults.clear());
                                },
                              ),
                            const SizedBox(width: 4),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blueAccent.withOpacity(0.2),
                              child: const Icon(Icons.person, size: 20, color: Colors.blueAccent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 280),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E).withOpacity(0.85),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _searchResults.length,
                              separatorBuilder: (c, i) => const Divider(color: Colors.white12, height: 1),
                              itemBuilder: (context, index) {
                                final item = _searchResults[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.place, color: Colors.white54, size: 20)
                                  ),
                                  title: Text(
                                    item['display_name'], 
                                    style: const TextStyle(color: Colors.white, fontSize: 15), 
                                    maxLines: 2, 
                                    overflow: TextOverflow.ellipsis
                                  ),
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    final lat = double.parse(item['lat']);
                                    final lon = double.parse(item['lon']);
                                    final destination = LatLng(lat, lon);
                                    
                                    setState(() {
                                      _searchController.text = item['display_name'].split(',').first;
                                      _searchResults.clear();
                                    });
                                    
                                    _calculateRoute(destination, vehicle: _selectedVehicle);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          if (!_isNavigating && _primaryRoute != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16, 
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 6))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildVehicleOption('driving', Icons.directions_car),
                            _buildVehicleOption('bike', Icons.directions_bike),
                            _buildVehicleOption('foot', Icons.directions_walk),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(color: Colors.white12, height: 1),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: _isRouting 
                                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 3))
                                  : Icon(
                                      _selectedVehicle == 'driving' ? Icons.directions_car :
                                      _selectedVehicle == 'bike' ? Icons.directions_bike : Icons.directions_walk,
                                      color: Colors.blueAccent,
                                      size: 28,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _primaryRoute!.duration,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _primaryRoute!.distance,
                                      style: const TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: _startNavigation,
                              child: const Text("Start", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white38, size: 28),
                              onPressed: () {
                                setState(() {
                                  _primaryRoute = null;
                                  _alternateRoutes.clear();
                                  _markers.removeWhere((m) => m.key == const Key('destination'));
                                  _currentDestination = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: (_isNavigating || _primaryRoute == null) ? 32 : 280,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGlassFab(
                  icon: Icons.my_location,
                  color: Colors.blueAccent,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _findMyVessel();
                  }
                ),
                const SizedBox(height: 16),
                _buildGlassFab(
                  icon: Icons.add_alert,
                  color: Colors.redAccent,
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    if (_myLocation != null) {
                      _showAddHurdleDialog(_myLocation!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Locating you first...')),
                      );
                      _findMyVessel().then((_) {
                        if (_myLocation != null) _showAddHurdleDialog(_myLocation!);
                      });
                    }
                  }
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddHurdleDialog(LatLng position) async {
    String type = 'pothole';
    String description = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              color: const Color(0xFF1C1C1E).withOpacity(0.9),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 24, right: 24, top: 16
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const Text('Report a Hazard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          value: type,
                          dropdownColor: const Color(0xFF2C2C2E),
                          iconEnabledColor: Colors.white54,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          items: ['pothole', 'flooding', 'accessibility', 'other']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                              .toList(),
                          onChanged: (val) {
                            setModalState(() => type = val ?? type);
                          },
                          decoration: InputDecoration(
                            labelText: 'Hazard Type',
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (val) => description = val,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Description (e.g., Deep water)',
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              await _submitHurdle(position, type, description);
                            },
                            child: const Text('Submit Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                }
              ),
            ),
          ),
        );
      }
    );
  }

  Future<void> _submitHurdle(LatLng position, String type, String description) async {
    final int tempId = DateTime.now().millisecondsSinceEpoch;
    
    setState(() {
      _markers.add(
        Marker(
          key: Key('hurdle_$tempId'),
          point: position,
          width: 44, height: 44,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showHurdleDetails({
                'id': tempId,
                'latitude': position.latitude,
                'longitude': position.longitude,
                'type': type,
                'description': description,
                'reliabilityScore': 1, 
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2), 
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: const Icon(Icons.error, color: Colors.redAccent, size: 20),
                ),
              ],
            ),
          ),
        ),
      );
    });

    final String postUrl = "http://10.214.193.85:8000/api/complaints/"; 
    try {
      final response = await http.post(
        Uri.parse(postUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'lat': position.latitude,
          'lng': position.longitude,
          'hurdle_type': type,
          'description': description,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchHurdlesInView();
      }
    } catch (e) {
      print("Network realm severed: $e");
    }
  }

  Future<void> _deleteHurdle(dynamic hurdleId) async {
    setState(() {
      _markers.removeWhere((m) => m.key == Key('hurdle_$hurdleId'));
    });
    
    final String deleteUrl = "http://10.214.193.85:8000/api/complaints/$hurdleId";
    try {
      await http.delete(Uri.parse(deleteUrl));
    } catch (e) {
      print("Delete failed: $e");
    }
    _fetchHurdlesInView();
  }

  Future<void> _castVote(dynamic hurdleId, bool isActive) async {
    final String voteUrl = "http://10.214.193.85:8000/api/complaints/$hurdleId/vote";
    try {
      final response = await http.post(
        Uri.parse(voteUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'is_active': isActive}),
      );

      if (response.statusCode == 200) {
        _fetchHurdlesInView(); 
      }
    } catch (e) {
      print("Network connection failed: $e");
    }
  }

  void _showHurdleDetails(Map<String, dynamic> hurdle) {
    final int score = hurdle['reliabilityScore'] ?? 0;
    final bool isVerified = score > 0;
    
    // Attempt to pull real votes count if the backend sends it, fallback to the reliability score tally
    final int realUpvotes = hurdle['upvotes'] ?? hurdle['votes_count'] ?? hurdle['votes'] ?? 0;
    final int reports = realUpvotes > 0 ? realUpvotes : (score.abs() + 1); 

    // Handle both potential backend keys
    final String displayType = (hurdle['type'] ?? hurdle['hurdle_type'] ?? 'unknown').toString().toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              color: const Color(0xFF1C1C1E).withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (isVerified ? Colors.redAccent : Colors.orangeAccent).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVerified ? Icons.error : Icons.warning_amber_rounded, 
                            color: isVerified ? Colors.redAccent : Colors.orangeAccent, 
                            size: 32
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    displayType,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.verified, color: Colors.blueAccent, size: 22),
                                  ]
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people, size: 16, color: Colors.white54),
                                      const SizedBox(width: 6),
                                      Text(
                                        "$reports Reports",
                                        style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    isVerified ? "Status: Accepted" : "Needs Verification",
                                    style: TextStyle(
                                      color: isVerified ? Colors.greenAccent : Colors.orangeAccent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "DESCRIPTION",
                      style: TextStyle(fontSize: 13, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hurdle['description'] ?? 'No description provided.',
                      style: const TextStyle(fontSize: 17, height: 1.5, color: Colors.white),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        if (!isVerified) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent.withOpacity(0.2),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact(); 
                                Navigator.pop(context); 
                                _castVote(hurdle['id'], true); 
                              },
                              icon: const Icon(Icons.thumb_up_alt_rounded, color: Colors.greenAccent),
                              label: const Text("Verify", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.05),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact(); 
                              Navigator.pop(context); 
                              setState(() {
                                _hiddenHurdles.add(hurdle['id']);
                                _markers.removeWhere((m) => m.key == Key('hurdle_${hurdle['id']}'));
                              });
                              _castVote(hurdle['id'], false); 
                            },
                            icon: const Icon(Icons.thumb_down_alt_rounded, color: Colors.white54),
                            label: const Text("Resolved", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.redAccent.withOpacity(0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            Navigator.pop(context);
                            setState(() {
                              _hiddenHurdles.add(hurdle['id']);
                            });
                            _deleteHurdle(hurdle['id']);
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 26),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}