import 'dart:async';

import 'package:latlong2/latlong.dart';

import 'location_service.dart';

/// Debug-only fake GPS so the app can be exercised on a desktop without
/// GeoClue (screenshots, UI testing). Enabled in debug/profile builds with
/// `NAV_SIMULATE_LOCATION="lat,lon[,heading[,speedMps]]"`; never in release.
class SimulatedLocationService extends LocationService {
  SimulatedLocationService(this.fix);

  final LocationFix fix;
  Timer? _timer;

  static SimulatedLocationService? fromEnvironment(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split(',').map((e) => double.tryParse(e.trim()));
    final v = parts.toList();
    if (v.length < 2 || v[0] == null || v[1] == null) return null;
    return SimulatedLocationService(
      LocationFix(
        position: LatLng(v[0]!, v[1]!),
        accuracyMeters: 5,
        heading: v.length > 2 ? v[2] : null,
        speedMps: v.length > 3 ? v[3] : 0,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<LocationPermissionState> ensurePermission() async {
    permissionState = LocationPermissionState.granted;
    return permissionState;
  }

  @override
  Future<void> start({bool navigating = false}) async {
    permissionState = LocationPermissionState.granted;
    publishFix(fix);
    _timer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => publishFix(fix),
    );
  }

  @override
  Future<LocationFix?> getCurrent() async {
    publishFix(fix);
    return fix;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await super.dispose();
  }
}
