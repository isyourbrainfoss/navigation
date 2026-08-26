import 'dart:async';
import 'dart:io';

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
    this.altitudeMeters,
    required this.timestamp,
  });

  final LatLng position;
  final double accuracyMeters;
  final double? heading;
  final double? speedMps;
  final double? altitudeMeters;
  final DateTime timestamp;
}

/// GPS wrapper with permission handling for Android + Linux (GeoClue).
class LocationService {
  LocationService({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Browse GPS stops after this much UI idle. GPS ticks do not count.
  static const idleAfter = Duration(seconds: 60);

  final DateTime Function() _clock;
  StreamSubscription<Position>? _sub;
  final _controller = StreamController<LocationFix>.broadcast();
  final _errorController = StreamController<Object>.broadcast();
  Timer? _idleTimer;
  LocationPermissionState permissionState = LocationPermissionState.unknown;
  LocationFix? lastFix;
  DateTime? lastFixAt;
  DateTime? _lastActivityAt;
  bool _navigating = false;
  bool _starting = false;
  Object? lastError;

  Stream<LocationFix> get fixes => _controller.stream;
  Stream<Object> get errors => _errorController.stream;
  bool get isListening => _sub != null;

  /// True when browsing and the UI has been untouched for [idleAfter].
  /// GPS ticks do not count as activity — otherwise the stream never idles.
  bool get isIdle {
    if (_navigating) return false;
    final latest = _lastActivityAt;
    if (latest == null) return false;
    return _clock().difference(latest) > idleAfter;
  }

  void noteUserActivity() {
    _lastActivityAt = _clock();
    if (_navigating || isListening || _starting) return;
    if (permissionState != LocationPermissionState.granted) return;
    unawaited(start(navigating: false));
  }

  /// Test helper: a GPS fix must not refresh [_lastActivityAt].
  @visibleForTesting
  void ingestFix(LocationFix fix) {
    lastFix = fix;
    lastFixAt = _clock();
    lastError = null;
    if (!_controller.isClosed) _controller.add(fix);
  }

  /// Test helper: pretend the platform stream is open without GeoClue.
  @visibleForTesting
  void attachDummySubscription() {
    _sub ??= const Stream<Position>.empty().listen((_) {});
  }

  Future<LocationPermissionState> ensurePermission() async {
    try {
      if (Platform.isLinux) {
        // geolocator_linux: checkPermission is unableToDetermine,
        // requestPermission is unimplemented, and the GNOME dconf
        // location toggle often fails inside Flatpak. GeoClue is the
        // authority — only fail when the stream/getCurrent throws.
        try {
          await Geolocator.isLocationServiceEnabled();
        } catch (e) {
          debugPrint('isLocationServiceEnabled (linux): $e');
        }
        permissionState = LocationPermissionState.granted;
        lastError = null;
        return permissionState;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        permissionState = LocationPermissionState.serviceDisabled;
        lastError = 'Location services are disabled';
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
        _ => LocationPermissionState.granted,
      };
      if (permissionState == LocationPermissionState.granted) {
        lastError = null;
      }
      return permissionState;
    } catch (e, st) {
      debugPrint('ensurePermission failed: $e\n$st');
      lastError = e;
      if (Platform.isLinux) {
        permissionState = LocationPermissionState.granted;
        return permissionState;
      }
      permissionState = LocationPermissionState.denied;
      return permissionState;
    }
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
      return _publish(pos);
    } catch (e, st) {
      debugPrint('getCurrent failed: $e\n$st');
      lastError = e;
      return lastFix;
    }
  }

  LocationSettings _streamSettings({required bool navigating}) {
    final accuracy = navigating
        ? LocationAccuracy.bestForNavigation
        : LocationAccuracy.medium;
    final distanceFilter = navigating ? 2 : 25;
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        foregroundNotificationConfig: navigating
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Navigation',
                notificationText: 'Turn-by-turn is using GPS',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );
  }

  Future<void> start({bool navigating = false}) async {
    if (_starting) return;
    _starting = true;
    _navigating = navigating;
    _lastActivityAt = _clock();
    _armIdleTimer();
    try {
      final state = await ensurePermission();
      if (state != LocationPermissionState.granted) return;
      await stop();
      _navigating = navigating;
      final settings = _streamSettings(navigating: navigating);
      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) {
          _publish(pos);
          permissionState = LocationPermissionState.granted;
        },
        onError: (Object e, StackTrace st) {
          debugPrint('position stream error: $e\n$st');
          lastError = e;
          if (Platform.isLinux) {
            permissionState = LocationPermissionState.serviceDisabled;
          }
          if (!_errorController.isClosed) _errorController.add(e);
        },
      );
    } finally {
      _starting = false;
    }
  }

  /// Restart the stream at browsing vs navigation accuracy if already listening.
  Future<void> setBrowsingDuty({required bool navigating}) async {
    if (_navigating == navigating && isListening) return;
    _navigating = navigating;
    if (!isListening) return;
    await start(navigating: navigating);
  }

  /// Stop the GPS stream when browsing and the UI has been idle.
  Future<void> pauseIfIdle({required bool navigating}) async {
    if (navigating) {
      _navigating = true;
      return;
    }
    _navigating = false;
    if (isIdle && isListening) {
      await stop();
    }
  }

  void _armIdleTimer() {
    _idleTimer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      if (isIdle && isListening) {
        unawaited(pauseIfIdle(navigating: _navigating));
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    await stop();
    await _controller.close();
    await _errorController.close();
  }

  /// GeoClue often reports heading 0 when stationary — that is not north.
  double? _validHeading(Position pos) {
    if (!pos.heading.isFinite || pos.heading < 0) return null;
    final speed = pos.speed.isFinite ? pos.speed : 0.0;
    if (speed < 0.6) return null;
    if (pos.heading == 0 && speed < 1.5) return null;
    return pos.heading;
  }

  LocationFix _publish(Position pos) {
    final fix = _toFix(pos);
    lastFix = fix;
    lastFixAt = _clock();
    lastError = null;
    if (!_controller.isClosed) _controller.add(fix);
    return fix;
  }

  LocationFix _toFix(Position pos) {
    return LocationFix(
      position: LatLng(pos.latitude, pos.longitude),
      accuracyMeters: pos.accuracy,
      heading: _validHeading(pos),
      speedMps: pos.speed >= 0 && pos.speed.isFinite ? pos.speed : null,
      altitudeMeters:
          pos.altitude.isFinite && pos.altitude.abs() > 0.01 ? pos.altitude : null,
      timestamp: pos.timestamp,
    );
  }
}
