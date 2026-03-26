import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Map',
      home: MapScreen(),
    );
  }
}

class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) => LatLng(
        begin!.latitude + (end!.latitude - begin!.latitude) * t,
        begin!.longitude + (end!.longitude - begin!.longitude) * t,
      );
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.mapController});

  final MapController? mapController;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  LatLng? _currentLocation;
  LatLng? _displayedLocation;
  final List<LatLng> _routePoints = [];
  bool _loading = true;
  String? _errorMessage;
  StreamSubscription<Position>? _positionSubscription;

  late final AnimationController _zoomAnimController;
  late final Animation<double> _zoomAnim;
  var _zoomTween = Tween<double>(begin: 15, end: 15);

  late final AnimationController _locationAnimController;
  var _locationTween = _LatLngTween(
    begin: const LatLng(0, 0),
    end: const LatLng(0, 0),
  );

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();

    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _zoomAnim = CurvedAnimation(
      parent: _zoomAnimController,
      curve: Curves.easeInOut,
    );
    _zoomAnim.addListener(_onZoomAnim);

    _locationAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _locationAnimController.addListener(_onLocationAnim);

    _determinePosition();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _zoomAnimController.dispose();
    _locationAnimController.dispose();
    super.dispose();
  }

  void _onZoomAnim() {
    _mapController.move(
      _mapController.camera.center,
      _zoomTween.transform(_zoomAnim.value),
    );
  }

  void _onLocationAnim() {
    setState(() {
      _displayedLocation = _locationTween.lerp(
        Curves.easeInOut.transform(_locationAnimController.value),
      );
    });
  }

  void _centerOnPin() {
    _mapController.move(_currentLocation!, _mapController.camera.zoom);
  }

  void _animateZoom(double delta) {
    _zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: _mapController.camera.zoom + delta,
    );
    _zoomAnimController
      ..stop()
      ..reset()
      ..forward();
  }

  void _animateToLocation(LatLng newLocation) {
    if (_displayedLocation != null) {
      setState(() => _routePoints.add(_displayedLocation!));
    }
    _locationTween = _LatLngTween(
      begin: _displayedLocation ?? newLocation,
      end: newLocation,
    );
    _locationAnimController
      ..stop()
      ..reset()
      ..forward();
  }

  Future<void> _determinePosition() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _routePoints.clear();
    });

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission denied.';
          _loading = false;
        });
        return;
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).listen(
        (position) {
          final newLocation = LatLng(position.latitude, position.longitude);
          setState(() {
            _currentLocation = newLocation;
            _loading = false;
          });
          _animateToLocation(newLocation);
        },
        onError: (Object e) {
          setState(() {
            _errorMessage = 'Could not get location: $e';
            _loading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not get location: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _determinePosition,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final markerLocation = _displayedLocation ?? _currentLocation!;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation!,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'io.beta',
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty && _displayedLocation != null)
                    Polyline(
                      points: [..._routePoints, _displayedLocation!],
                      strokeWidth: 4,
                      color: Colors.blue.withValues(alpha: 0.7),
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: markerLocation,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 32,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'center_pin',
                  onPressed: _centerOnPin,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () => _animateZoom(1),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () => _animateZoom(-1),
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
