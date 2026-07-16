import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationPermissionState {
  unknown,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class LocationFix {
  const LocationFix({
    required this.position,
    required this.accuracyMeters,
    this.heading,
    this.speedMps,
    required this.timestamp,
  });

  final LatLng position;
  final double accuracyMeters;
  final double? heading;
  final double? speedMps;
  final DateTime timestamp;
}

/// GPS wrapper with permission handling for Android + Linux (GeoClue).
class LocationService {
  StreamSubscription<Position>? _sub;
  final _controller = StreamController<LocationFix>.broadcast();
  LocationPermissionState permissionState = LocationPermissionState.unknown;
  LocationFix? lastFix;

  Stream<LocationFix> get fixes => _controller.stream;
  bool get isListening => _sub != null;

  Future<LocationPermissionState> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      permissionState = LocationPermissionState.serviceDisabled;
      return permissionState;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    permissionState = switch (permission) {
      LocationPermission.denied => LocationPermissionState.denied,
      LocationPermission.deniedForever => LocationPermissionState.deniedForever,
      LocationPermission.whileInUse ||
      LocationPermission.always =>
        LocationPermissionState.granted,
      _ => LocationPermissionState.denied,
    };
    return permissionState;
  }

  Future<LocationFix?> getCurrent() async {
    final state = await ensurePermission();
    if (state != LocationPermissionState.granted) return lastFix;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final fix = _toFix(pos);
      lastFix = fix;
      if (!_controller.isClosed) _controller.add(fix);
      return fix;
    } catch (e, st) {
      debugPrint('getCurrent failed: $e\n$st');
      return lastFix;
    }
  }

  Future<void> start() async {
    final state = await ensurePermission();
    if (state != LocationPermissionState.granted) return;
    await stop();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        final fix = _toFix(pos);
        lastFix = fix;
        if (!_controller.isClosed) _controller.add(fix);
      },
      onError: (Object e, StackTrace st) {
        debugPrint('position stream error: $e\n$st');
      },
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  LocationFix _toFix(Position pos) {
    return LocationFix(
      position: LatLng(pos.latitude, pos.longitude),
      accuracyMeters: pos.accuracy,
      heading: pos.heading >= 0 ? pos.heading : null,
      speedMps: pos.speed >= 0 ? pos.speed : null,
      timestamp: pos.timestamp,
    );
  }
}
