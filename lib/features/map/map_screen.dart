import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/geometry.dart';
import '../../core/map_style.dart';
import '../../core/theme/navigation_theme.dart';
import '../../models/camera_view.dart';
import '../../models/place.dart';
import '../../models/route_plan.dart';
import '../../providers/app_providers.dart';
import '../../services/location_service.dart';
import '../navigate/guidance_banner.dart';
import '../navigate/route_preview_sheet.dart';
import '../offline/offline_sheet.dart';
import '../onboarding/location_intro.dart';
import '../search/search_sheet.dart';
import '../settings/settings_screen.dart';
import '../tracks/tracks_sheet.dart';
import 'widgets/attribution_chip.dart';
import 'widgets/destination_pin.dart';
import 'widgets/glass.dart';
import 'widgets/map_controls.dart';
import 'widgets/place_peek.dart';
import 'widgets/speed_capsule.dart';
import 'widgets/user_puck.dart';
import 'widgets/voice_status.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _mapController = MapController();
  StreamSubscription<LocationFix>? _fixSub;
  StreamSubscription<Object>? _errorSub;
  bool _didCenterOnUser = false;
  double _mapRotation = 0;
  int _lastSpokenInstruction = -1;
  Ticker? _ticker;
  LatLng? _camPos;
  LatLng? _camTarget;
  double _camZoom = AppConstants.defaultZoom;
  double _camZoomTarget = AppConstants.defaultZoom;
  double _camRotTarget = 0;
  bool _smoothFollow = false;
  late final LatLng _initialCenter;
  late final double _initialZoom;
  late final double _initialRotation;

  static const _fallback = LatLng(52.52, 13.405);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final saved = ref.read(settingsRepositoryProvider).loadCamera();
    if (saved != null) {
      _initialCenter = LatLng(saved.latitude, saved.longitude);
      _initialZoom = saved.zoom;
      _initialRotation = saved.rotation;
      _camPos = _initialCenter;
      _camTarget = _initialCenter;
      _camZoom = saved.zoom;
      _camZoomTarget = saved.zoom;
      _mapRotation = saved.rotation;
      _camRotTarget = saved.rotation;
      _didCenterOnUser = true;
    } else {
      _initialCenter = _fallback;
      _initialZoom = AppConstants.defaultZoom;
      _initialRotation = 0;
    }
    _ticker = createTicker(_onCameraTick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreCamera();
      _bootstrapLocation();
      final initial = ref.read(initialDestinationProvider);
      if (initial != null) {
        ref.read(mapSessionProvider.notifier).selectDestination(initial);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _persistCamera();
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(locationServiceProvider).noteUserActivity();
    }
  }

  void _noteActivity() {
    ref.read(locationServiceProvider).noteUserActivity();
  }

  void _onCameraTick(Duration _) {
    if (!_smoothFollow || _camTarget == null || !mounted) return;
    _camPos ??= _camTarget;
    const k = 0.2;
    final next = GeoMath.lerpLatLng(_camPos!, _camTarget!, k);
    _camZoom += (_camZoomTarget - _camZoom) * k;
    _mapRotation = GeoMath.lerpAngleDegrees(_mapRotation, _camRotTarget, k);
    _camPos = next;
    _mapController.moveAndRotate(next, _camZoom, _mapRotation);
  }

  double _zoomForNav({
    required TravelMode mode,
    required double? speedMps,
    required double metersTo,
  }) {
    if (metersTo < 70) return 18.0;
    if (mode == TravelMode.walk) return AppConstants.walkZoom;
    final kmh = (speedMps ?? 0) * 3.6;
    if (kmh < 20) return 17.3;
    if (kmh < 50) return 16.4;
    if (kmh < 90) return 15.6;
    return AppConstants.highwayZoom;
  }

  void _restoreCamera() {
    final saved = ref.read(settingsRepositoryProvider).loadCamera();
    if (saved == null) return;
    _camPos = LatLng(saved.latitude, saved.longitude);
    _camTarget = _camPos;
    _camZoom = saved.zoom;
    _camZoomTarget = saved.zoom;
    _mapRotation = saved.rotation;
    _camRotTarget = saved.rotation;
    _mapController.moveAndRotate(
      LatLng(saved.latitude, saved.longitude),
      saved.zoom,
      saved.rotation,
    );
  }

  void _persistCamera() {
    try {
      final cam = _mapController.camera;
      ref.read(settingsRepositoryProvider).saveCamera(
            CameraView(
              latitude: cam.center.latitude,
              longitude: cam.center.longitude,
              zoom: cam.zoom,
              rotation: cam.rotation,
            ),
          );
    } catch (_) {}
  }

  Future<void> _bootstrapLocation() async {
    final location = ref.read(locationServiceProvider);
    final settings = ref.read(settingsProvider);
    final state = await location.ensurePermission();
    ref.read(locationPermissionProvider.notifier).state = state;
    if (state == LocationPermissionState.granted) {
      await location.start();
      final fix = await location.getCurrent();
      if (fix != null && mounted && !_didCenterOnUser) {
        _didCenterOnUser = true;
        if (settings.followOnStart &&
            ref.read(settingsRepositoryProvider).loadCamera() == null) {
          _mapController.move(fix.position, AppConstants.defaultZoom);
        }
      }
    }
    _fixSub = location.fixes.listen(_onFix);
    _errorSub = location.errors.listen((e) {
      if (!mounted) return;
      ref.read(locationPermissionProvider.notifier).state =
          location.permissionState;
      ref.read(locationErrorProvider.notifier).state = e.toString();
    });
    if (location.lastError != null) {
      ref.read(locationErrorProvider.notifier).state =
          location.lastError.toString();
    }
    final intro = ref.read(settingsRepositoryProvider);
    if (!intro.loadLocationIntroSeen() && mounted) {
      final enable = await showLocationIntro(context);
      await intro.setLocationIntroSeen();
      if (enable && mounted) {
        final s = await location.ensurePermission();
        ref.read(locationPermissionProvider.notifier).state = s;
        if (s == LocationPermissionState.granted) {
          await location.start();
        } else {
          try {
            await Geolocator.openLocationSettings();
          } catch (_) {}
        }
      }
    }
  }

  void _onFix(LocationFix fix) {
    if (!mounted) return;
    if (ref.read(locationErrorProvider) != null) {
      ref.read(locationErrorProvider.notifier).state = null;
    }
    final session = ref.read(mapSessionProvider);
    final settings = ref.read(settingsProvider);
    final recorder = ref.read(trackRecorderProvider);
    recorder.addFix(fix);

    if (!_didCenterOnUser && session.followUser) {
      _didCenterOnUser = true;
      _mapController.move(fix.position, AppConstants.defaultZoom);
    }

    if (session.phase == NavPhase.navigating && session.route != null) {
      final engine = ref.read(navigationEngineProvider);
      final progress = engine.update(
        fix: fix,
        route: session.route!,
        instructionIndex: session.instructionIndex,
        wasOffRoute: session.progress?.offRoute ?? false,
        hintSegment: session.progress?.segmentIndex,
      );
      ref.read(mapSessionProvider.notifier).applyProgress(progress);

      if (progress.arrived) {
        ref.read(voiceServiceProvider).onProgress(
              progress: progress,
              metric: settings.metricUnits,
              enabled: settings.voiceEnabled && !session.muted,
              modeName: session.mode.name,
              speedMps: fix.speedMps ?? 0,
            );
        if (settings.haptics) {
          HapticFeedback.heavyImpact();
        }
        return;
      }

      if (progress.instructionIndex != _lastSpokenInstruction) {
        _lastSpokenInstruction = progress.instructionIndex;
        if (settings.haptics) HapticFeedback.mediumImpact();
      }
      ref.read(voiceServiceProvider).onProgress(
            progress: progress,
            metric: settings.metricUnits,
            enabled: settings.voiceEnabled && !session.muted,
            modeName: session.mode.name,
            speedMps: fix.speedMps ?? 0,
          );
      ref.read(mapSessionProvider.notifier).maybeReroute(progress);

      if (session.followUser) {
        final heading = (fix.heading != null && (fix.speedMps ?? 0) > 0.6)
            ? fix.heading!
            : progress.routeHeading;
        final zoom = _zoomForNav(
          mode: session.mode,
          speedMps: fix.speedMps,
          metersTo: progress.metersToNextManeuver,
        );
        final look = (fix.speedMps ?? 0) * 3.6 < 40 ? 48.0 : 95.0;
        final center = session.followMode == FollowMode.courseUp
            ? GeoMath.offset(progress.snapped, heading, look)
            : progress.snapped;
        _camTarget = center;
        _camZoomTarget = zoom;
        _camRotTarget =
            session.followMode == FollowMode.courseUp ? -heading : 0;
        _smoothFollow = true;
        _camPos ??= center;
      }
    } else if (session.followUser && session.phase == NavPhase.browsing) {
      _camTarget = fix.position;
      _camZoomTarget = _mapController.camera.zoom;
      _camRotTarget = 0;
      _smoothFollow = true;
      _camPos ??= fix.position;
    }
  }

  @override
  void dispose() {
    _persistCamera();
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.dispose();
    _fixSub?.cancel();
    _errorSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _openSearch({bool alongRoute = false}) async {
    _noteActivity();
    final location = ref.read(locationServiceProvider);
    final bias = location.lastFix?.position ?? _mapController.camera.center;
    final place = await showSearchSheet(
      context,
      bias: bias,
      alongRoute: alongRoute,
    );
    if (place != null && mounted) {
      ref.read(mapSessionProvider.notifier).setFollowUser(false);
      _mapController.move(
        place.latLng,
        math.max(_mapController.camera.zoom, 15),
      );
      await ref.read(mapSessionProvider.notifier).selectDestination(place);
      _fitRoute();
    }
  }

  Future<void> _onLongPress(TapPosition tap, LatLng latlng) async {
    _noteActivity();
    var place = Place.fromLatLng(latlng);
    try {
      place = await ref.read(searchServiceProvider).reverse(latlng) ?? place;
    } catch (_) {}
    if (!mounted) return;
    ref.read(mapSessionProvider.notifier).setPin(place);
    final go = await showPlacePeek(context, place: place);
    if (!mounted) return;
    if (go == 'go') {
      await ref.read(mapSessionProvider.notifier).selectDestination(place);
      _fitRoute();
    } else if (go == 'via') {
      await ref.read(mapSessionProvider.notifier).addVia(place);
    } else if (go == 'save') {
      await ref.read(favoritesRepositoryProvider).addFavorite(place);
      ref.read(favoritesListProvider.notifier).state =
          ref.read(favoritesRepositoryProvider).loadFavorites();
    }
  }

  Future<void> _recenter() async {
    _noteActivity();
    final location = ref.read(locationServiceProvider);
    final session = ref.read(mapSessionProvider);
    if (session.followUser) {
      ref.read(mapSessionProvider.notifier).cycleFollowMode();
    } else {
      ref.read(mapSessionProvider.notifier).setFollowUser(true);
    }
    _smoothFollow = true;
    final fix = location.lastFix ?? await location.getCurrent();
    if (fix != null && mounted) {
      final s = ref.read(mapSessionProvider);
      final zoom = _mapController.camera.zoom;
      _camZoom = zoom;
      _camZoomTarget = zoom;
      _camPos = fix.position;
      _camTarget = fix.position;
      if (s.followMode == FollowMode.northUp) {
        _mapRotation = 0;
        _camRotTarget = 0;
        _mapController.moveAndRotate(fix.position, zoom, 0);
      } else {
        final heading = fix.heading ?? s.progress?.routeHeading ?? 0;
        _mapRotation = -heading;
        _camRotTarget = -heading;
        _mapController.moveAndRotate(fix.position, zoom, _mapRotation);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for GPS fix…')),
      );
    }
  }

  void _northUp() {
    _mapRotation = 0;
    _mapController.rotate(0);
    ref.read(mapSessionProvider.notifier).setFollowMode(FollowMode.northUp);
  }

  void _fitRoute() {
    final route = ref.read(mapSessionProvider).route;
    if (route == null || route.geometry.length < 2) return;
    final padding = MediaQuery.paddingOf(context);
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: route.geometry,
        padding: EdgeInsets.fromLTRB(
          48,
          padding.top + 140,
          48,
          padding.bottom + 240,
        ),
        maxZoom: 16,
      ),
    );
  }

  void _zoomBy(double delta) {
    final cam = _mapController.camera;
    final z = (cam.zoom + delta).clamp(
      AppConstants.minZoom,
      AppConstants.maxZoom,
    );
    _camZoom = z;
    _camZoomTarget = z;
    _mapController.move(cam.center, z);
  }

  Future<void> _openMore(
    BuildContext context, {
    required String styleKey,
    required String urlTemplate,
  }) async {
    _noteActivity();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.timeline),
                title: const Text('Tracks & GPX'),
                onTap: () {
                  Navigator.pop(ctx);
                  showTracksSheet(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Offline maps'),
                onTap: () {
                  Navigator.pop(ctx);
                  showOfflineSheet(
                    context,
                    center: _mapController.camera.center,
                    styleKey: styleKey,
                    urlTemplate: urlTemplate,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(mapSessionProvider);
    final settings = ref.watch(settingsProvider);
    final permission = ref.watch(locationPermissionProvider);
    final location = ref.watch(locationServiceProvider);
    final tiles = ref.watch(tileCacheServiceProvider);
    final night = ref.watch(nightDrivingActiveProvider);
    final platformBrightness = Theme.of(context).brightness;
    final style = resolveMapStyle(
      settings: settings,
      platform: platformBrightness,
      nightDriving: night,
    );
    final tileProvider = tiles.createProvider(
      styleKey: style.styleKey,
      urlTemplate: style.urlTemplate,
    );

    final userPos = location.lastFix?.position;
    final accuracy = location.lastFix?.accuracyMeters;
    final heading = location.lastFix?.heading;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final padding = MediaQuery.paddingOf(context);

    final route = session.route;
    List<LatLng> traveled = const [];
    List<LatLng> remaining = const [];
    if (route != null && route.geometry.length >= 2) {
      if (session.progress != null) {
        final split = GeoMath.splitAt(
          path: route.geometry,
          snapped: session.progress!.snapped,
          segmentIndex: session.progress!.segmentIndex,
        );
        traveled = split.traveled;
        remaining = split.remaining;
      } else {
        remaining = route.geometry;
      }
    }

    final displayPos = (session.phase == NavPhase.navigating &&
            session.progress != null &&
            session.progress!.offRouteMeters < AppConstants.snapDisplayMeters)
        ? session.progress!.snapped
        : userPos;

    final interactions = settings.rotationLock
        ? InteractiveFlag.all & ~InteractiveFlag.rotate
        : InteractiveFlag.all;

    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: _initialZoom,
        initialRotation: _initialRotation,
        minZoom: AppConstants.minZoom,
        maxZoom: AppConstants.maxZoom,
        backgroundColor:
            style.dark ? const Color(0xFF0D1117) : const Color(0xFFE8EEF4),
        interactionOptions: InteractionOptions(flags: interactions),
        onMapEvent: (event) {
          if (event is MapEventMove ||
              event is MapEventRotate ||
              event is MapEventScrollWheelZoom) {
            final src = event.source;
            final userGesture = src == MapEventSource.dragStart ||
                src == MapEventSource.onDrag ||
                src == MapEventSource.dragEnd ||
                src == MapEventSource.multiFingerGestureStart ||
                src == MapEventSource.onMultiFinger ||
                src == MapEventSource.multiFingerEnd ||
                src == MapEventSource.scrollWheel ||
                src == MapEventSource.doubleTapHold ||
                src == MapEventSource.flingAnimationController;
            if (userGesture) {
              _noteActivity();
              if (ref.read(mapSessionProvider).followUser) {
                ref.read(mapSessionProvider.notifier).setFollowUser(false);
                _smoothFollow = false;
              }
            }
            if (src == MapEventSource.dragEnd ||
                src == MapEventSource.multiFingerEnd) {
              _persistCamera();
            }
          }
          if (event is MapEventRotate) {
            setState(() => _mapRotation = _mapController.camera.rotation);
          }
        },
        onLongPress: _onLongPress,
      ),
      children: [
        ColorFiltered(
          colorFilter: style.invertTiles
              // Keyless dark map: luminance-inverted OSM tiles.
              ? const ColorFilter.matrix(<double>[
                  -0.2126, -0.7152, -0.0722, 0, 255,
                  -0.2126, -0.7152, -0.0722, 0, 255,
                  -0.2126, -0.7152, -0.0722, 0, 255,
                  0, 0, 0, 1, 0,
                ])
              : night
              ? const ColorFilter.matrix(<double>[
                  1.08, 0, 0, 0, 0,
                  0, 0.90, 0, 0, 0,
                  0, 0, 0.72, 0, 0,
                  0, 0, 0, 1, 0,
                ])
              : const ColorFilter.matrix(<double>[
                  1, 0, 0, 0, 0,
                  0, 1, 0, 0, 0,
                  0, 0, 1, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
          child: TileLayer(
            urlTemplate: style.urlTemplate,
            userAgentPackageName: AppConstants.packageId,
            tileProvider: tileProvider,
            maxNativeZoom: 19,
            keepBuffer: 2,
            retinaMode: MediaQuery.devicePixelRatioOf(context) >= 1.5,
          ),
        ),
        if (session.overlayTrack != null &&
            session.overlayTrack!.latLngs.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: session.overlayTrack!.latLngs,
                strokeWidth: 4,
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
        if (session.phase == NavPhase.preview)
          for (var i = 0; i < session.alternatives.length; i++)
            if (i != session.routeIndex &&
                session.alternatives[i].geometry.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: session.alternatives[i].geometry,
                    strokeWidth: 6,
                    color: const Color(0x66818CF8),
                  ),
                ],
              ),
        if (traveled.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: traveled,
                strokeWidth: 7,
                color: NavigationTheme.routeTraveled,
              ),
            ],
          ),
        if (remaining.length >= 2)
          PolylineLayer(
            polylines: [
              if (night)
                Polyline(
                  points: remaining,
                  strokeWidth: 16,
                  color: NavigationTheme.routeNight.withValues(alpha: 0.22),
                ),
              Polyline(
                points: remaining,
                strokeWidth: 6,
                color: night
                    ? NavigationTheme.routeNight
                    : NavigationTheme.routeColor,
                borderStrokeWidth: 4,
                borderColor: night
                    ? NavigationTheme.routeCasingNight
                    : NavigationTheme.routeOutline,
              ),
            ],
          ),
        if (userPos != null && accuracy != null && accuracy > 6)
          CircleLayer(
            circles: [
              CircleMarker(
                point: userPos,
                radius: accuracy,
                useRadiusInMeter: true,
                color: const Color(0x332563EB),
                borderStrokeWidth: 1,
                borderColor: const Color(0x662563EB),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (session.destination != null)
              Marker(
                point: session.destination!.latLng,
                width: 40,
                height: 48,
                alignment: Alignment.topCenter,
                child: const DestinationPin(),
              ),
            if (session.phase == NavPhase.browsing)
              for (final recent in ref.watch(recentsListProvider).take(8))
                Marker(
                  point: recent.latLng,
                  width: 22,
                  height: 22,
                  child: const Icon(Icons.circle, size: 10, color: Color(0xFF64748B)),
                ),
            for (var i = 0; i < session.vias.length; i++)
              Marker(
                point: session.vias[i].latLng,
                width: 28,
                height: 28,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFF7C3AED),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            for (final sample in GeoMath.samplesAlong(
              remaining,
              spacingMeters: 90,
              maxSamples: 18,
            ))
              Marker(
                point: sample.point,
                width: 18,
                height: 18,
                child: RouteChevron(
                  bearing: sample.bearing,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            if (session.pin != null &&
                session.destination?.id != session.pin!.id)
              Marker(
                point: session.pin!.latLng,
                width: 36,
                height: 36,
                child: Icon(
                  Icons.push_pin,
                  color: Theme.of(context).colorScheme.tertiary,
                  size: 32,
                ),
              ),
            if (displayPos != null)
              Marker(
                point: displayPos,
                width: 72,
                height: 72,
                child: UserPuck(
                  headingDegrees: session.followUser &&
                          session.followMode == FollowMode.courseUp
                      ? 0
                      : heading ?? session.progress?.routeHeading,
                  accuracyMeters: accuracy,
                  navigating: session.phase == NavPhase.navigating,
                ),
              ),
          ],
        ),
        if (settings.showScaleBar &&
            session.phase != NavPhase.navigating &&
            session.phase != NavPhase.arrived)
          Scalebar(
            alignment: Alignment.bottomLeft,
            padding: EdgeInsets.fromLTRB(12, 0, 0, padding.bottom + 72),
            textStyle: TextStyle(
              color: style.dark ? Colors.white : Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            lineColor: style.dark ? Colors.white : Colors.black87,
          ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(right: 8, bottom: padding.bottom + 4),
            child: AttributionChip(text: style.attribution),
          ),
        ),
      ],
    );

    final gnss = location.lastFix;
    final gnssChip = gnss == null
        ? (permission == LocationPermissionState.granted
            ? Glass(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Waiting for GPS…',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink())
        : Glass(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              [
                formatAccuracy(gnss.accuracyMeters),
                if (gnss.altitudeMeters != null)
                  formatAltitude(
                    gnss.altitudeMeters!,
                    metric: settings.metricUnits,
                  ),
                if (gnss.speedMps != null && settings.showSpeed)
                  formatSpeed(gnss.speedMps!, metric: settings.metricUnits),
              ].join(' · '),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          );

    final browsing = session.phase == NavPhase.browsing;
    final favorites = ref.watch(favoritesListProvider);
    final home = favorites.where((p) => p.role == PlaceRole.home);
    final work = favorites.where((p) => p.role == PlaceRole.work);
    final parked = favorites.where((p) => p.role == PlaceRole.parked);

    final fabs = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_mapRotation.abs() > 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CompassRose(
              rotationDegrees: _mapRotation,
              onNorthUp: _northUp,
            ),
          ),
        if (session.phase != NavPhase.navigating &&
            session.phase != NavPhase.arrived) ...[
          ZoomControls(
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
          ),
          const SizedBox(height: 10),
        ],
        RoundMapButton(
          icon: session.followMode == FollowMode.courseUp
              ? Icons.navigation
              : Icons.my_location,
          tooltip: session.followMode == FollowMode.courseUp
              ? 'Course up'
              : 'My location',
          onPressed: _recenter,
          highlighted: session.followUser,
        ),
        if (session.phase != NavPhase.navigating &&
            session.phase != NavPhase.arrived) ...[
          const SizedBox(height: 10),
          RoundMapButton(
            icon: Icons.more_horiz,
            tooltip: 'More',
            onPressed: () => _openMore(
              context,
              styleKey: style.styleKey,
              urlTemplate: style.urlTemplate,
            ),
          ),
        ],
      ],
    );

    final topChrome = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          children: [
            if (session.phase == NavPhase.navigating ||
                session.phase == NavPhase.arrived)
              const GuidanceBanner(),
            if (session.progress?.offRoute == true &&
                session.phase == NavPhase.navigating &&
                !session.holdRoute)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Material(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.rerouting
                                ? 'Recalculating…'
                                : 'Off route — hold your heading or wait for a new path',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(mapSessionProvider.notifier)
                              .stayOnThisRoute(),
                          child: const Text('Stay'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            VoiceStatusBanner(
              reason: ref.watch(voiceServiceProvider).unavailableReason,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                gnssChip,
                const Spacer(),
                if (session.phase == NavPhase.navigating &&
                    settings.showSpeed &&
                    gnss?.speedMps != null)
                  SpeedCapsule(
                    speedMps: gnss!.speedMps!,
                    metric: settings.metricUnits,
                  ),
                const Spacer(),
                if (ref.watch(isRecordingProvider))
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                      label: Text('REC'),
                    ),
                  ),
                if (session.overlayTrack != null)
                  ActionChip(
                    label: Text(session.overlayTrack!.name),
                    onPressed: () => ref
                        .read(mapSessionProvider.notifier)
                        .setOverlayTrack(null),
                    avatar: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
            if (browsing &&
                (home.isNotEmpty || work.isNotEmpty || parked.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (home.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.home_outlined, size: 18),
                          label: const Text('Home'),
                          onPressed: () => ref
                              .read(mapSessionProvider.notifier)
                              .selectDestination(home.first),
                        ),
                      ),
                    if (work.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.work_outline, size: 18),
                          label: const Text('Work'),
                          onPressed: () => ref
                              .read(mapSessionProvider.notifier)
                              .selectDestination(work.first),
                        ),
                      ),
                    if (parked.isNotEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.local_parking, size: 18),
                        label: const Text('Parked'),
                        onPressed: () => ref
                            .read(mapSessionProvider.notifier)
                            .selectDestination(parked.first),
                      ),
                  ],
                ),
              ),
            if (permission != LocationPermissionState.granted &&
                permission != LocationPermissionState.unknown)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _PermissionBanner(
                  state: permission,
                  detail: ref.watch(locationErrorProvider) ??
                      location.lastError?.toString(),
                  onRequest: () async {
                    final s = await ref
                        .read(locationServiceProvider)
                        .ensurePermission();
                    ref.read(locationPermissionProvider.notifier).state = s;
                    if (s == LocationPermissionState.granted) {
                      await ref.read(locationServiceProvider).start();
                      await _recenter();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );

    final previewBottom = session.phase == NavPhase.preview
        ? MediaQuery.sizeOf(context).height * 0.22 + 12
        : 88.0;

    Widget body;
    if (landscape &&
        (session.phase == NavPhase.navigating ||
            session.phase == NavPhase.arrived)) {
      body = Row(
        children: [
          SizedBox(
            width: math.min(360, MediaQuery.sizeOf(context).width * 0.42),
            child: const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: GuidanceBanner(),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                map,
                Positioned(right: 12, bottom: 24, child: SafeArea(child: fabs)),
              ],
            ),
          ),
        ],
      );
    } else {
      body = Stack(
        children: [
          map,
          topChrome,
          Positioned(
            right: 12,
            bottom: previewBottom,
            child: SafeArea(child: fabs),
          ),
          if (session.phase == NavPhase.preview)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: 0,
              child: RoutePreviewBar(onFitRoute: _fitRoute),
            ),
          if (browsing)
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GlassSearch(
                    onTap: _openSearch,
                    trailing: session.route != null
                        ? IconButton(
                            tooltip: 'Along route',
                            onPressed: () => _openSearch(alongRoute: true),
                            icon: const Icon(Icons.alt_route),
                          )
                        : null,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.equal): () => _zoomBy(1),
        const SingleActivator(LogicalKeyboardKey.add): () => _zoomBy(1),
        const SingleActivator(LogicalKeyboardKey.minus): () => _zoomBy(-1),
        const SingleActivator(LogicalKeyboardKey.keyN): _northUp,
        const SingleActivator(LogicalKeyboardKey.audioVolumeUp): () =>
            _zoomBy(1),
        const SingleActivator(LogicalKeyboardKey.audioVolumeDown): () =>
            _zoomBy(-1),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          ref.read(mapSessionProvider.notifier).cancelPreview();
        },
        const SingleActivator(LogicalKeyboardKey.keyM): () {
          final s = ref.read(mapSessionProvider);
          ref.read(mapSessionProvider.notifier).setMuted(!s.muted);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(body: body),
      ),
    );
  }
}

class _GlassSearch extends StatelessWidget {
  const _GlassSearch({required this.onTap, this.trailing});
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Glass(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.search, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Search places',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({
    required this.state,
    required this.onRequest,
    this.detail,
  });
  final LocationPermissionState state;
  final VoidCallback onRequest;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = switch (state) {
      LocationPermissionState.serviceDisabled =>
        'Location services are off. Enable GeoClue / GPS for navigation.',
      LocationPermissionState.deniedForever =>
        'Location permission denied. Enable it in system settings.',
      _ => 'Location permission needed for navigation.',
    };
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                detail == null ? text : '$text\n$detail',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onRequest,
              child: Text(
                'Enable',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
