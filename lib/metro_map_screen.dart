import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'main.dart'; // To access deadzoneEngine
import 'deadzone_engine.dart';
import 'dart:math';
import 'dart:async';
import 'services/ble_crowd_scanner.dart';
import 'models/graph_edge.dart';

class LiveTrain {
  String id;
  String lineId;
  GraphEdge edge;
  double progress;
  int crowdScore;
  LiveTrain(this.id, this.lineId, this.edge, this.progress, this.crowdScore);
}

class MetroMapScreen extends StatefulWidget {
  final bool showLiveTrains;
  const MetroMapScreen({Key? key, this.showLiveTrains = true}) : super(key: key);

  @override
  State<MetroMapScreen> createState() => _MetroMapScreenState();
}

class _MetroMapScreenState extends State<MetroMapScreen> {
  final MapController _mapController = MapController();
  RouteResult? _currentRoute;
  String? _originId;
  String? _destinationId;
  LatLng? _currentLocation;
  BleCrowdScanner? _bleScanner;
  List<LiveTrain> _liveTrains = [];
  Timer? _trainTimer;
  
  @override
  void initState() {
    super.initState();
    _bleScanner = BleCrowdScanner(deadzoneEngine);
    _initLocationAndBle();
    _initLiveTrains();
  }

  void _initLiveTrains() {
    final rand = Random();
    for (final edges in deadzoneEngine.activeGraph.adjacency.values) {
      for (final edge in edges) {
        if (edge.lineId != null && rand.nextDouble() < 0.15) { // 15% chance to have a train on an edge
          _liveTrains.add(LiveTrain('T${rand.nextInt(9000)+1000}', edge.lineId!, edge, rand.nextDouble(), rand.nextInt(100)));
        }
      }
    }
    _trainTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        for (var t in _liveTrains) {
          t.progress += 1.0 / t.edge.travelTimeSeconds;
          if (t.progress >= 1.0) {
            final nextEdges = deadzoneEngine.activeGraph.adjacency[t.edge.toStationId]?.where((e) => e.lineId == t.lineId).toList();
            if (nextEdges != null && nextEdges.isNotEmpty) {
              final nextEdge = nextEdges.firstWhere((e) => e.toStationId != t.edge.fromStationId, orElse: () => nextEdges.first);
              t.edge = nextEdge;
              t.progress = 0.0;
              t.crowdScore = (t.crowdScore + rand.nextInt(20) - 10).clamp(0, 100);
            } else {
              t.progress = 0.0;
            }
          }
        }
      });
    });
  }

  Future<void> _initLocationAndBle() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
      _bleScanner?.startScanning();
    }
  }

  @override
  void dispose() {
    _bleScanner?.stopScanning();
    _trainTimer?.cancel();
    super.dispose();
  }

  void _planRoute() {
    if (_originId != null && _destinationId != null) {
      final route = deadzoneEngine.findRoute(
        originStationId: _originId!,
        destinationStationId: _destinationId!,
      );
      setState(() {
        _currentRoute = route;
      });
      if (route != null && route.fullPath.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(
          route.fullPath.map((s) => LatLng(s.latitude, s.longitude)).toList()
        );
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)));
      }
    }
  }

  void _clearRoute() {
    setState(() {
      _originId = null;
      _destinationId = null;
      _currentRoute = null;
    });
  }

  Color _hexToColor(String? hex, {Color fallback = Colors.grey}) {
    if (hex == null || hex.isEmpty) return fallback;
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.tryParse(hex, radix: 16) ?? fallback.value);
  }

  Color _getCrowdColor(int score) {
    if (score < 40) return const Color(0xFF87b871); // Calm
    if (score < 70) return const Color(0xFFe4b953); // Moderate
    return const Color(0xFFe18a63); // Busy
  }

  @override
  Widget build(BuildContext context) {
    final stations = deadzoneEngine.getStationsForCurrentCity();
    final isInDeadzone = deadzoneEngine.isInDeadzone;
    final allCongestion = deadzoneEngine.getAllStationCongestion();

    final markers = stations.map((s) {
      final isSelected = s.id == _originId || s.id == _destinationId;
      final congestion = allCongestion[s.id];
      final score = congestion?.score ?? 0;
      final markerColor = isSelected ? const Color(0xFF1b775f) : Colors.white;
      
      return Marker(
        point: LatLng(s.latitude, s.longitude),
        width: 120,
        height: 60,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            if (_originId == null) {
              setState(() => _originId = s.id);
            } else if (_destinationId == null && _originId != s.id) {
              setState(() => _destinationId = s.id);
              _planRoute();
            } else {
              _clearRoute();
              setState(() => _originId = s.id);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: isSelected ? 30 : 16,
                    height: isSelected ? 30 : 16,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getCrowdColor(score),
                        width: isSelected ? 6 : 3,
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                  if (isSelected) 
                    const Icon(Icons.location_on, size: 16, color: Colors.white),
                ],
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s.name, 
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle)),
              Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)])),
            ],
          ),
        )
      );
    }

    if (widget.showLiveTrains) {
      for (final t in _liveTrains) {
        final s1 = deadzoneEngine.activeGraph.stations[t.edge.fromStationId]!;
        final s2 = deadzoneEngine.activeGraph.stations[t.edge.toStationId]!;
        final lat = s1.latitude + (s2.latitude - s1.latitude) * t.progress;
        final lng = s1.longitude + (s2.longitude - s1.longitude) * t.progress;
        final trainColor = _getCrowdColor(t.crowdScore);
        
        markers.add(Marker(
          point: LatLng(lat, lng),
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 16, height: 16,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: trainColor, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                child: Center(child: Icon(Icons.train, size: 8, color: _hexToColor(deadzoneEngine.activeGraph.lines[t.lineId]?.colorHex))),
              ),
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(color: trainColor, shape: BoxShape.circle),
                  child: Text('${t.crowdScore}', style: const TextStyle(fontSize: 6, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ));
      }
    }

    List<Polyline> polylines = [];
    if (_currentRoute != null) {
      for (final segment in _currentRoute!.segments) {
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
      // Draw entire network
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Disha · Delhi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(
              isInDeadzone ? 'Offline Network Engine Active' : 'Live Train Feed Connected',
              style: TextStyle(
                fontSize: 11, 
                color: isInDeadzone ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF142321),
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(isInDeadzone ? Icons.signal_wifi_off : Icons.wifi, 
              color: isInDeadzone ? Colors.orange : const Color(0xFF1b775f)),
            tooltip: 'Toggle Offline Engine',
            onPressed: () {
              setState(() {
                if (isInDeadzone) {
                  deadzoneEngine.triggerCellularHeartbeat();
                } else {
                  deadzoneEngine.enterSubterraneanDeadzone();
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(deadzoneEngine.isInDeadzone 
                    ? 'Entering Deadzone (Offline Local Routing Active)' 
                    : 'Surfacing (Live Sync Restored)'
                  ),
                  backgroundColor: const Color(0xFF142321),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(28.6139, 77.2090),
              initialZoom: 12,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.disha.metro_one',
              ),
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),
          
          // Floating Search / Route Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 420),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Plan Journey', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          if (_originId != null || _destinationId != null)
                            TextButton(
                              onPressed: _clearRoute,
                              child: const Text('Clear', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: _originId != null ? const Color(0xFF1b775f) : Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.circular(16),
                                color: Theme.of(context).scaffoldBackgroundColor,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('FROM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  Autocomplete<String>(
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                                      return stations.map((e) => e.name).where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                    },
                                    onSelected: (String selection) {
                                      final station = stations.firstWhere((s) => s.name == selection);
                                      setState(() {
                                        _originId = station.id;
                                        _planRoute();
                                      });
                                    },
                                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                                      if (_originId != null && !focusNode.hasFocus) {
                                        controller.text = _getStationName(_originId!);
                                      } else if (_originId == null && !focusNode.hasFocus) {
                                        controller.text = '';
                                      }
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _originId != null ? Colors.black : Colors.black87),
                                        decoration: const InputDecoration(
                                          hintText: 'Search or tap map',
                                          hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: _destinationId != null ? const Color(0xFF1b775f) : Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.circular(16),
                                color: Theme.of(context).scaffoldBackgroundColor,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('TO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  Autocomplete<String>(
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                                      return stations.map((e) => e.name).where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                    },
                                    onSelected: (String selection) {
                                      final station = stations.firstWhere((s) => s.name == selection);
                                      setState(() {
                                        _destinationId = station.id;
                                        _planRoute();
                                      });
                                    },
                                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                                      if (_destinationId != null && !focusNode.hasFocus) {
                                        controller.text = _getStationName(_destinationId!);
                                      } else if (_destinationId == null && !focusNode.hasFocus) {
                                        controller.text = '';
                                      }
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _destinationId != null ? Colors.black : Colors.black87),
                                        decoration: const InputDecoration(
                                          hintText: 'Search or tap map',
                                          hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_originId != null && _destinationId == null) ...[
                        const SizedBox(height: 16),
                        Builder(
                          builder: (ctx) {
                            final score = deadzoneEngine.getAllStationCongestion()[_originId]?.score ?? 0;
                            final isCrowded = score > 40;
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: isCrowded ? Colors.red[200]! : Colors.green[200]!), borderRadius: BorderRadius.circular(16)),
                              child: Row(
                                children: [
                                  Icon(isCrowded ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: isCrowded ? Colors.red : Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Current crowd at ${_getStationName(_originId!)} is at $score% capacity. ${isCrowded ? "Expect delays." : "Normal boarding."}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isCrowded ? Colors.red : Colors.green)),
                                  ),
                                ],
                              ),
                            );
                          }
                        ),
                      ],
                      if (_currentRoute != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFeef5ed),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1b775f).withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${_currentRoute!.totalMinutes} min', 
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1b775f))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isInDeadzone ? Colors.orange[100] : const Color(0xFFc7ee72),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isInDeadzone ? 'Offline Route' : 'Fastest Route',
                                      style: TextStyle(
                                        fontSize: 10, 
                                        fontWeight: FontWeight.bold, 
                                        color: isInDeadzone ? Colors.orange[900] : const Color(0xFF142321)
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ..._currentRoute!.segments.map((segment) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        segment.isTransfer ? Icons.directions_walk : Icons.subway,
                                        size: 16,
                                        color: segment.isTransfer ? Colors.grey : _hexToColor(segment.line?.colorHex, fallback: const Color(0xFF1b775f)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          segment.isTransfer 
                                            ? 'Transfer at ${segment.fromStation.name}'
                                            : '${segment.line?.name} from ${segment.fromStation.name}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
  
  String _getStationName(String id) {
    return deadzoneEngine.getStationsForCurrentCity().firstWhere((s) => s.id == id).name;
  }
}
