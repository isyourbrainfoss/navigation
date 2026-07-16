import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../core/geometry.dart';
import '../../core/theme/navigation_theme.dart';
import '../../models/app_settings.dart';
import '../../models/place.dart';
import '../../providers/app_providers.dart';
import '../../services/location_service.dart';
import '../navigate/guidance_banner.dart';
import '../navigate/route_preview_sheet.dart';
import '../offline/offline_sheet.dart';
import '../search/search_sheet.dart';
import '../settings/settings_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  StreamSubscription<LocationFix>? _fixSub;
  bool _didCenterOnUser = false;
  double _mapRotation = 0;

  // Default: central Europe until GPS arrives.
  static const _fallback = LatLng(52.52, 13.405);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapLocation());
  }

  Future<void> _bootstrapLocation() async {
    final location = ref.read(locationServiceProvider);
    final state = await location.ensurePermission();
    ref.read(locationPermissionProvider.notifier).state = state;
    if (state == LocationPermissionState.granted) {
      await location.start();
      final fix = await location.getCurrent();
      if (fix != null && mounted && !_didCenterOnUser) {
        _didCenterOnUser = true;
        _mapController.move(fix.position, AppConstants.defaultZoom);
      }
    }
    _fixSub = location.fixes.listen(_onFix);
  }

  void _onFix(LocationFix fix) {
    if (!mounted) return;
    final session = ref.read(mapSessionProvider);
    final settings = ref.read(settingsProvider);

    if (!_didCenterOnUser && session.followUser) {
      _didCenterOnUser = true;
      _mapController.move(fix.position, AppConstants.defaultZoom);
    }

    if (session.phase == NavPhase.navigating) {
      _updateGuidance(fix);
      if (session.followUser) {
        final zoom = AppConstants.navZoom;
        if (settings.courseUp &&
            fix.heading != null &&
            (fix.speedMps ?? 0) > 0.8) {
          _mapRotation = -fix.heading!;
          _mapController.moveAndRotate(fix.position, zoom, _mapRotation);
        } else {
          _mapController.move(fix.position, zoom);
        }
      }
    } else if (session.followUser && session.phase == NavPhase.browsing) {
      // Gentle follow only if user hasn't panned away intentionally —
      // we only auto-move when follow is explicitly on.
      _mapController.move(fix.position, _mapController.camera.zoom);
    }
  }

  void _updateGuidance(LocationFix fix) {
    final session = ref.read(mapSessionProvider);
    final route = session.route;
    if (route == null || route.geometry.isEmpty) return;

    final distToEnd = GeoMath.haversineMeters(
      fix.position,
      route.destination.latLng,
    );
    if (distToEnd <= AppConstants.arrivalMeters) {
      ref.read(mapSessionProvider.notifier).markArrived();
      return;
    }

    final nearest = GeoMath.nearestOnPolyline(fix.position, route.geometry);
    if (nearest.meters > AppConstants.offRouteMeters) {
      // Re-route from current position.
      ref.read(mapSessionProvider.notifier).computeRoute().then((_) {
        final s = ref.read(mapSessionProvider);
        if (s.route != null && s.phase == NavPhase.preview) {
          ref.read(mapSessionProvider.notifier).startNavigation();
        }
      });
      return;
    }

    // Advance instruction index by nearest maneuver.
    if (route.instructions.isNotEmpty) {
      var best = 0;
      var bestD = double.infinity;
      for (var i = 0; i < route.instructions.length; i++) {
        final d = GeoMath.haversineMeters(
          fix.position,
          route.instructions[i].location,
        );
        // Prefer upcoming instructions along the route (not ones behind).
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      // If we're past the current step start, move to next.
      final current = session.instructionIndex;
      if (best >= current) {
        ref.read(mapSessionProvider.notifier).setInstructionIndex(best);
      } else if (current < route.instructions.length - 1) {
        final step = route.instructions[current];
        final dStep = GeoMath.haversineMeters(fix.position, step.location);
        if (dStep < 20 && step.distanceMeters < 30) {
          ref
              .read(mapSessionProvider.notifier)
              .setInstructionIndex(current + 1);
        }
      }
    }
  }

  @override
  void dispose() {
    _fixSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  bool _useDarkTiles(AppSettings settings, Brightness platform) {
    return switch (settings.mapStyle) {
      MapStylePreference.light => false,
      MapStylePreference.dark => true,
      MapStylePreference.auto => platform == Brightness.dark,
    };
  }

  Future<void> _openSearch() async {
    final location = ref.read(locationServiceProvider);
    final bias = location.lastFix?.position ?? _mapController.camera.center;
    final place = await showSearchSheet(context, bias: bias);
    if (place != null && mounted) {
      ref.read(mapSessionProvider.notifier).setFollowUser(false);
      _mapController.move(place.latLng, math.max(_mapController.camera.zoom, 15));
      await ref.read(mapSessionProvider.notifier).selectDestination(place);
    }
  }

  Future<void> _onLongPress(TapPosition tap, LatLng latlng) async {
    final place = Place.fromLatLng(latlng);
    ref.read(mapSessionProvider.notifier).setPin(place);
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pinned location',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${latlng.latitude.toStringAsFixed(5)}, '
                  '${latlng.longitude.toStringAsFixed(5)}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate here'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (go == true && mounted) {
      await ref.read(mapSessionProvider.notifier).selectDestination(place);
    }
  }

  Future<void> _recenter() async {
    final location = ref.read(locationServiceProvider);
    ref.read(mapSessionProvider.notifier).setFollowUser(true);
    final fix = location.lastFix ?? await location.getCurrent();
    if (fix != null && mounted) {
      final session = ref.read(mapSessionProvider);
      final zoom = session.phase == NavPhase.navigating
          ? AppConstants.navZoom
          : AppConstants.defaultZoom;
      _mapRotation = 0;
      _mapController.moveAndRotate(fix.position, zoom, 0);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for GPS fix…')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(mapSessionProvider);
    final settings = ref.watch(settingsProvider);
    final permission = ref.watch(locationPermissionProvider);
    final location = ref.watch(locationServiceProvider);
    final tiles = ref.watch(tileCacheServiceProvider);
    final platformBrightness = Theme.of(context).brightness;
    final darkTiles = _useDarkTiles(settings, platformBrightness);
    final styleKey = darkTiles ? 'dark' : 'light';
    final urlTemplate =
        darkTiles ? AppConstants.tileUrlDark : AppConstants.tileUrlLight;
    final tileProvider = tiles.createProvider(
      styleKey: styleKey,
      urlTemplate: urlTemplate,
    );

    final userPos = location.lastFix?.position;
    final accuracy = location.lastFix?.accuracyMeters;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userPos ?? _fallback,
              initialZoom: AppConstants.defaultZoom,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              backgroundColor: darkTiles
                  ? const Color(0xFF0D1117)
                  : const Color(0xFFE8EEF4),
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
                  if (userGesture && ref.read(mapSessionProvider).followUser) {
                    ref.read(mapSessionProvider.notifier).setFollowUser(false);
                  }
                }
              },
              onLongPress: _onLongPress,
            ),
            children: [
              TileLayer(
                urlTemplate: urlTemplate,
                userAgentPackageName: AppConstants.packageId,
                tileProvider: tileProvider,
                maxNativeZoom: 19,
                keepBuffer: 2,
              ),
              if (session.route != null && session.route!.geometry.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: session.route!.geometry,
                      strokeWidth: 8,
                      color: NavigationTheme.routeOutline.withValues(alpha: 0.85),
                      borderStrokeWidth: 0,
                    ),
                    Polyline(
                      points: session.route!.geometry,
                      strokeWidth: 5,
                      color: NavigationTheme.routeColor,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (session.destination != null)
                    Marker(
                      point: session.destination!.latLng,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFE11D48),
                        size: 40,
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
                  if (userPos != null)
                    Marker(
                      point: userPos,
                      width: 28,
                      height: 28,
                      child: _UserDot(accuracy: accuracy),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution(
                    AppConstants.tileAttribution,
                  ),
                ],
                alignment: AttributionAlignment.bottomLeft,
              ),
            ],
          ),

          // Top chrome
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  if (session.phase == NavPhase.navigating ||
                      session.phase == NavPhase.arrived)
                    const GuidanceBanner()
                  else
                    _SearchBarButton(onTap: _openSearch),
                  if (permission != LocationPermissionState.granted &&
                      permission != LocationPermissionState.unknown)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _PermissionBanner(
                        state: permission,
                        onRequest: () async {
                          final s = await ref
                              .read(locationServiceProvider)
                              .ensurePermission();
                          ref.read(locationPermissionProvider.notifier).state =
                              s;
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
          ),

          // Side FABs
          if (session.phase != NavPhase.navigating)
            Positioned(
              right: 12,
              bottom: session.phase == NavPhase.preview ? 220 : 24,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundFab(
                      icon: Icons.my_location,
                      tooltip: 'My location',
                      onPressed: _recenter,
                      highlighted: session.followUser,
                    ),
                    const SizedBox(height: 10),
                    _RoundFab(
                      icon: Icons.download_outlined,
                      tooltip: 'Offline maps',
                      onPressed: () {
                        showOfflineSheet(
                          context,
                          center: _mapController.camera.center,
                          styleKey: styleKey,
                          urlTemplate: urlTemplate,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _RoundFab(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned(
              right: 12,
              bottom: 24,
              child: SafeArea(
                child: _RoundFab(
                  icon: Icons.my_location,
                  tooltip: 'Recenter',
                  onPressed: _recenter,
                  highlighted: session.followUser,
                ),
              ),
            ),

          // Route preview
          if (session.phase == NavPhase.preview)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RoutePreviewBar(),
            ),
        ],
      ),
    );
  }
}

class _SearchBarButton extends StatelessWidget {
  const _SearchBarButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface.withValues(alpha: 0.96),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundFab extends StatelessWidget {
  const _RoundFab({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 3,
      shape: const CircleBorder(),
      color: highlighted
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface.withValues(alpha: 0.96),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: highlighted
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot({this.accuracy});
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2563EB),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.state, required this.onRequest});
  final LocationPermissionState state;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = switch (state) {
      LocationPermissionState.serviceDisabled =>
        'Location services are off. Enable them for navigation.',
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
                text,
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
