import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../core/sun.dart';
import '../models/app_settings.dart';
import '../models/nav_progress.dart';
import '../models/offline_region.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import '../models/track.dart';
import '../services/favorites_repository.dart';
import '../services/gpx_service.dart';
import '../services/keep_awake_service.dart';
import '../services/location_service.dart';
import '../services/navigation_engine.dart';
import '../services/notification_service.dart';
import '../services/routing_service.dart';
import '../services/search_service.dart';
import '../services/settings_repository.dart';
import '../services/tile_cache_service.dart';
import '../services/track_repository.dart';
import '../services/voice_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('Override settingsRepositoryProvider in main');
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  throw UnimplementedError('Override favoritesRepositoryProvider in main');
});

final locationServiceProvider = Provider<LocationService>((ref) {
  throw UnimplementedError('Override locationServiceProvider in main');
});

final searchServiceProvider = Provider<SearchService>((ref) {
  throw UnimplementedError('Override searchServiceProvider in main');
});

final routingServiceProvider = Provider<RoutingService>((ref) {
  throw UnimplementedError('Override routingServiceProvider in main');
});

final tileCacheServiceProvider = Provider<TileCacheService>((ref) {
  throw UnimplementedError('Override tileCacheServiceProvider in main');
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  throw UnimplementedError('Override voiceServiceProvider in main');
});

final keepAwakeServiceProvider = Provider<KeepAwakeService>((ref) {
  throw UnimplementedError('Override keepAwakeServiceProvider in main');
});

final trackRepositoryProvider = Provider<TrackRepository>((ref) {
  throw UnimplementedError('Override trackRepositoryProvider in main');
});

final gpxServiceProvider = Provider<GpxService>((ref) => GpxService());

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final navigationEngineProvider =
    Provider<NavigationEngine>((ref) => const NavigationEngine());

final initialDestinationProvider = StateProvider<Place?>((ref) => null);

final favoritesListProvider = StateProvider<List<Place>>((ref) {
  return ref.watch(favoritesRepositoryProvider).loadFavorites();
});

final recentsListProvider = StateProvider<List<Place>>((ref) {
  return ref.watch(favoritesRepositoryProvider).loadRecents();
});

final foldersListProvider = StateProvider<List<String>>((ref) {
  return ref.watch(favoritesRepositoryProvider).loadFolders();
});

final savedTracksProvider = StateProvider<List<SavedTrack>>((ref) {
  return ref.watch(trackRepositoryProvider).load();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._repo, AppSettings initial) : super(initial);

  final SettingsRepository _repo;

  Future<void> update(AppSettings settings) async {
    state = settings;
    await _repo.save(settings);
  }

  Future<void> setTheme(ThemePreference theme) =>
      update(state.copyWith(theme: theme));

  Future<void> setMapStyle(MapStylePreference style) =>
      update(state.copyWith(mapStyle: style));

  Future<void> setMetricUnits(bool metric) =>
      update(state.copyWith(metricUnits: metric));

  Future<void> setCourseUp(bool value) =>
      update(state.copyWith(courseUp: value));

  Future<void> setFollowOnStart(bool value) =>
      update(state.copyWith(followOnStart: value));

  Future<void> setVoiceEnabled(bool value) =>
      update(state.copyWith(voiceEnabled: value));

  Future<void> setKeepScreenOn(bool value) =>
      update(state.copyWith(keepScreenOn: value));

  Future<void> setRotationLock(bool value) =>
      update(state.copyWith(rotationLock: value));

  Future<void> setNightDriving(NightDriving value) =>
      update(state.copyWith(nightDriving: value));

  Future<void> setHaptics(bool value) =>
      update(state.copyWith(haptics: value));

  Future<void> setShowSpeed(bool value) =>
      update(state.copyWith(showSpeed: value));

  Future<void> setShowScaleBar(bool value) =>
      update(state.copyWith(showScaleBar: value));

  Future<void> setLargeHud(bool value) =>
      update(state.copyWith(largeHud: value));

  Future<void> setHighContrast(bool value) =>
      update(state.copyWith(highContrast: value));

  Future<void> setCustomRoutingUrl(String value) =>
      update(state.copyWith(customRoutingUrl: value));

  Future<void> setCartoApiKey(String value) =>
      update(state.copyWith(cartoApiKey: value.trim()));
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo, repo.load());
});

final locationFixProvider = StreamProvider<LocationFix?>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.fixes.map<LocationFix?>((f) => f);
});

final locationPermissionProvider =
    StateProvider<LocationPermissionState>((ref) {
  return ref.watch(locationServiceProvider).permissionState;
});

final locationErrorProvider = StateProvider<String?>((ref) => null);

final nightDrivingActiveProvider = Provider<bool>((ref) {
  final s = ref.watch(settingsProvider);
  switch (s.nightDriving) {
    case NightDriving.off:
      return false;
    case NightDriving.on:
      return true;
    case NightDriving.auto:
      final asyncFix = ref.watch(locationFixProvider);
      final fix = asyncFix.valueOrNull ??
          ref.watch(locationServiceProvider).lastFix;
      if (fix == null) {
        final h = DateTime.now().hour;
        return h < 6 || h >= 20;
      }
      return Sun.isNight(
        DateTime.now(),
        fix.position.latitude,
        fix.position.longitude,
      );
  }
});

enum NavPhase { browsing, preview, navigating, arrived }

enum FollowMode { northUp, courseUp }

class MapSession {
  const MapSession({
    this.phase = NavPhase.browsing,
    this.destination,
    this.mode = TravelMode.drive,
    this.route,
    this.alternatives = const [],
    this.routeIndex = 0,
    this.vias = const [],
    this.routeError,
    this.routing = false,
    this.rerouting = false,
    this.followUser = true,
    this.followMode = FollowMode.northUp,
    this.instructionIndex = 0,
    this.pin,
    this.progress,
    this.muted = false,
    this.overlayTrack,
    this.alongRouteQuery = '',
    this.holdRoute = false,
  });

  final NavPhase phase;
  final Place? destination;
  final TravelMode mode;
  final RoutePlan? route;
  final List<RoutePlan> alternatives;
  final int routeIndex;
  final List<Place> vias;
  final String? routeError;
  final bool routing;
  final bool rerouting;
  final bool followUser;
  final FollowMode followMode;
  final int instructionIndex;
  final Place? pin;
  final NavProgress? progress;
  final bool muted;
  final SavedTrack? overlayTrack;
  final String alongRouteQuery;
  final bool holdRoute;

  MapSession copyWith({
    NavPhase? phase,
    Place? destination,
    bool clearDestination = false,
    TravelMode? mode,
    RoutePlan? route,
    bool clearRoute = false,
    List<RoutePlan>? alternatives,
    int? routeIndex,
    List<Place>? vias,
    String? routeError,
    bool clearRouteError = false,
    bool? routing,
    bool? rerouting,
    bool? followUser,
    FollowMode? followMode,
    int? instructionIndex,
    Place? pin,
    bool clearPin = false,
    NavProgress? progress,
    bool clearProgress = false,
    bool? muted,
    SavedTrack? overlayTrack,
    bool clearOverlay = false,
    String? alongRouteQuery,
    bool? holdRoute,
  }) {
    return MapSession(
      phase: phase ?? this.phase,
      destination:
          clearDestination ? null : (destination ?? this.destination),
      mode: mode ?? this.mode,
      route: clearRoute ? null : (route ?? this.route),
      alternatives: alternatives ?? this.alternatives,
      routeIndex: routeIndex ?? this.routeIndex,
      vias: vias ?? this.vias,
      routeError: clearRouteError ? null : (routeError ?? this.routeError),
      routing: routing ?? this.routing,
      rerouting: rerouting ?? this.rerouting,
      followUser: followUser ?? this.followUser,
      followMode: followMode ?? this.followMode,
      instructionIndex: instructionIndex ?? this.instructionIndex,
      pin: clearPin ? null : (pin ?? this.pin),
      progress: clearProgress ? null : (progress ?? this.progress),
      muted: muted ?? this.muted,
      overlayTrack:
          clearOverlay ? null : (overlayTrack ?? this.overlayTrack),
      alongRouteQuery: alongRouteQuery ?? this.alongRouteQuery,
      holdRoute: holdRoute ?? this.holdRoute,
    );
  }
}

class MapSessionNotifier extends StateNotifier<MapSession> {
  MapSessionNotifier(this.ref) : super(const MapSession());

  final Ref ref;
  DateTime? _lastReroute;
  int _offRouteStreak = 0;
  bool _rerouteInFlight = false;

  @visibleForTesting
  void seed(MapSession value) => state = value;

  void setFollowUser(bool v) => state = state.copyWith(followUser: v);

  void cycleFollowMode() {
    final next = state.followMode == FollowMode.northUp
        ? FollowMode.courseUp
        : FollowMode.northUp;
    state = state.copyWith(followMode: next, followUser: true);
  }

  void setFollowMode(FollowMode mode) =>
      state = state.copyWith(followMode: mode);

  void setMuted(bool v) {
    state = state.copyWith(muted: v);
    ref.read(voiceServiceProvider).muted = v;
  }

  void setMode(TravelMode mode) {
    state = state.copyWith(mode: mode);
    if (state.destination != null) {
      computeRoute();
    }
  }

  void setPin(Place? place) {
    if (place == null) {
      state = state.copyWith(clearPin: true);
    } else {
      state = state.copyWith(pin: place);
    }
  }

  void setOverlayTrack(SavedTrack? track) {
    if (track == null) {
      state = state.copyWith(clearOverlay: true);
    } else {
      state = state.copyWith(overlayTrack: track);
    }
  }

  Future<void> addVia(Place place) async {
    final vias = [...state.vias, place];
    state = state.copyWith(vias: vias);
    if (state.destination != null) await computeRoute();
  }

  Future<void> removeVia(int index) async {
    if (index < 0 || index >= state.vias.length) return;
    final vias = [...state.vias]..removeAt(index);
    state = state.copyWith(vias: vias);
    if (state.destination != null) await computeRoute();
  }

  void selectAlternative(int index) {
    if (index < 0 || index >= state.alternatives.length) return;
    state = state.copyWith(
      routeIndex: index,
      route: state.alternatives[index],
      instructionIndex: 0,
      clearProgress: true,
    );
  }

  Future<void> selectDestination(Place place) async {
    final favs = ref.read(favoritesRepositoryProvider);
    await favs.addRecent(place);
    ref.read(recentsListProvider.notifier).state = favs.loadRecents();
    state = state.copyWith(
      destination: place,
      phase: NavPhase.preview,
      clearRoute: true,
      alternatives: const [],
      clearRouteError: true,
      clearPin: true,
      instructionIndex: 0,
      holdRoute: false,
    );
    await computeRoute();
  }

  Future<void> computeRoute({bool keepNavigating = false}) async {
    final dest = state.destination;
    if (dest == null) return;

    final location = ref.read(locationServiceProvider);
    var originFix = location.lastFix;
    originFix ??= await location.getCurrent();
    if (originFix == null) {
      state = state.copyWith(
        routing: false,
        routeError: 'Waiting for a GPS fix before routing.',
        clearRoute: true,
      );
      return;
    }

    final origin = Place.fromLatLng(originFix.position, name: 'Current location');
    final settings = ref.read(settingsProvider);

    state = state.copyWith(
      routing: !keepNavigating,
      rerouting: keepNavigating,
      clearRouteError: true,
    );
    try {
      final plans = await ref.read(routingServiceProvider).route(
            RouteRequest(
              origin: origin,
              destination: dest,
              mode: state.mode,
              vias: state.vias,
              alternatives: true,
              customBaseUrl: settings.customRoutingUrl,
            ),
          );
      if (plans.isEmpty) {
        throw RoutingException('No route found');
      }
      state = state.copyWith(
        route: plans.first,
        alternatives: plans,
        routeIndex: 0,
        routing: false,
        rerouting: false,
        phase: keepNavigating ? NavPhase.navigating : NavPhase.preview,
        instructionIndex: 0,
        followUser: keepNavigating ? true : state.followUser,
        clearProgress: true,
      );
      if (keepNavigating) {
        ref.read(voiceServiceProvider).reset();
      }
    } catch (e) {
      state = state.copyWith(
        routing: false,
        rerouting: false,
        routeError: e.toString(),
        clearRoute: keepNavigating ? false : true,
      );
    }
  }

  void stayOnThisRoute() {
    _offRouteStreak = 0;
    state = state.copyWith(holdRoute: true);
  }

  Future<void> startNavigation() async {
    if (state.route == null) return;
    state = state.copyWith(
      phase: NavPhase.navigating,
      followUser: true,
      holdRoute: false,
      followMode: (state.mode == TravelMode.walk || state.mode == TravelMode.bike)
          ? FollowMode.northUp
          : (ref.read(settingsProvider).courseUp
              ? FollowMode.courseUp
              : FollowMode.northUp),
      instructionIndex: 0,
    );
    _offRouteStreak = 0;
    ref.read(voiceServiceProvider).reset();
    await ref.read(locationServiceProvider).start(navigating: true);
    if (ref.read(settingsProvider).keepScreenOn) {
      await ref.read(keepAwakeServiceProvider).setActive(true);
    }
  }

  void cancelPreview() {
    state = state.copyWith(
      phase: NavPhase.browsing,
      clearRoute: true,
      alternatives: const [],
      vias: const [],
      clearRouteError: true,
      instructionIndex: 0,
      clearProgress: true,
      holdRoute: false,
    );
  }

  Future<void> stopNavigation({bool saveParked = true}) async {
    if (saveParked) {
      final fix = ref.read(locationServiceProvider).lastFix;
      if (fix != null) {
        await ref.read(favoritesRepositoryProvider).setRole(
              Place.fromLatLng(fix.position, name: 'Parked car'),
              PlaceRole.parked,
            );
        ref.read(favoritesListProvider.notifier).state =
            ref.read(favoritesRepositoryProvider).loadFavorites();
      }
    }
    await ref.read(keepAwakeServiceProvider).setActive(false);
    await ref.read(voiceServiceProvider).stop();
    ref.read(voiceServiceProvider).reset();
    await ref.read(locationServiceProvider).start(navigating: false);
    state = state.copyWith(
      phase: NavPhase.browsing,
      clearRoute: true,
      alternatives: const [],
      vias: const [],
      clearDestination: true,
      clearRouteError: true,
      instructionIndex: 0,
      clearProgress: true,
      holdRoute: false,
    );
  }

  void applyProgress(NavProgress progress) {
    final alreadyArrived = state.phase == NavPhase.arrived;
    state = state.copyWith(
      progress: progress,
      instructionIndex: progress.instructionIndex,
      phase: progress.arrived ? NavPhase.arrived : state.phase,
      followUser: progress.arrived
          ? false
          : (progress.approaching ? true : state.followUser),
    );
    if (progress.arrived && !alreadyArrived) {
      ref.read(keepAwakeServiceProvider).setActive(false);
    }
  }

  Future<void> maybeReroute(NavProgress progress) async {
    if (state.phase != NavPhase.navigating) return;
    if (state.holdRoute) return;
    if (!progress.offRoute) {
      _offRouteStreak = 0;
      return;
    }
    _offRouteStreak++;
    if (_offRouteStreak < AppConstants.offRouteConsecutiveFixes) return;
    if (_rerouteInFlight) return;
    final last = _lastReroute;
    if (last != null &&
        DateTime.now().difference(last) < AppConstants.rerouteCooldown) {
      return;
    }
    _rerouteInFlight = true;
    _lastReroute = DateTime.now();
    try {
      unawaited(ref.read(voiceServiceProvider).announceReroute());
      unawaited(ref.read(notificationServiceProvider).show(
            title: 'Recalculating',
            body: 'Finding a new route',
          ));
      await computeRoute(keepNavigating: true);
      if (state.route != null && state.phase == NavPhase.preview) {
        await startNavigation();
      }
    } finally {
      _rerouteInFlight = false;
      _offRouteStreak = 0;
    }
  }

  void setInstructionIndex(int i) {
    state = state.copyWith(instructionIndex: i);
  }

  void markArrived() {
    state = state.copyWith(phase: NavPhase.arrived, followUser: false);
    ref.read(keepAwakeServiceProvider).setActive(false);
  }

  Future<void> clearArrived() async {
    await stopNavigation(saveParked: true);
  }
}

final mapSessionProvider =
    StateNotifierProvider<MapSessionNotifier, MapSession>((ref) {
  return MapSessionNotifier(ref);
});

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.loading = false,
    this.error,
    this.category,
  });

  final String query;
  final List<Place> results;
  final bool loading;
  final String? error;
  final PoiCategory? category;

  SearchState copyWith({
    String? query,
    List<Place>? results,
    bool? loading,
    String? error,
    bool clearError = false,
    PoiCategory? category,
    bool clearCategory = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      category: clearCategory ? null : (category ?? this.category),
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this.ref) : super(const SearchState());

  final Ref ref;

  Future<void> search(String query, {LatLng? bias}) async {
    state = state.copyWith(
      query: query,
      loading: true,
      clearError: true,
      clearCategory: true,
    );
    if (query.trim().isEmpty) {
      state = state.copyWith(results: [], loading: false);
      return;
    }
    try {
      final results = await ref.read(searchServiceProvider).search(
            query,
            bias: bias,
          );
      if (state.query != query) return;
      state = state.copyWith(results: results, loading: false);
    } catch (e) {
      if (state.query != query) return;
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        results: [],
      );
    }
  }

  Future<void> searchCategory(PoiCategory category, {required LatLng bias}) async {
    state = state.copyWith(
      query: category.label,
      loading: true,
      category: category,
      clearError: true,
    );
    try {
      final results = await ref
          .read(searchServiceProvider)
          .searchCategory(category, bias: bias);
      state = state.copyWith(results: results, loading: false);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        results: [],
      );
    }
  }

  Future<void> searchAlongRoute(String query, {required RoutePlan route}) async {
    state = state.copyWith(query: query, loading: true, clearError: true);
    try {
      final results = await ref
          .read(searchServiceProvider)
          .searchAlongRoute(query, route: route);
      state = state.copyWith(results: results, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString(), results: []);
    }
  }

  void clear() => state = const SearchState();
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

class OfflineState {
  const OfflineState({
    this.regions = const [],
    this.progress,
    this.downloading = false,
    this.error,
  });

  final List<OfflineRegion> regions;
  final DownloadProgress? progress;
  final bool downloading;
  final String? error;

  OfflineState copyWith({
    List<OfflineRegion>? regions,
    DownloadProgress? progress,
    bool clearProgress = false,
    bool? downloading,
    String? error,
    bool clearError = false,
  }) {
    return OfflineState(
      regions: regions ?? this.regions,
      progress: clearProgress ? null : (progress ?? this.progress),
      downloading: downloading ?? this.downloading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OfflineNotifier extends StateNotifier<OfflineState> {
  OfflineNotifier(this.ref) : super(const OfflineState()) {
    _refresh();
    final cache = ref.read(tileCacheServiceProvider);
    _sub = cache.progress.listen((p) {
      state = state.copyWith(progress: p, downloading: true);
    });
  }

  final Ref ref;
  late final StreamSubscription<DownloadProgress> _sub;

  void _refresh() {
    final cache = ref.read(tileCacheServiceProvider);
    state = state.copyWith(
      regions: List.of(cache.regions),
      downloading: cache.isDownloading,
    );
  }

  Future<void> download({
    required String name,
    required LatLng center,
    required double radiusMeters,
    required String styleKey,
    required String urlTemplate,
  }) async {
    state = state.copyWith(downloading: true, clearError: true);
    try {
      await ref.read(tileCacheServiceProvider).downloadRegion(
            name: name,
            center: center,
            radiusMeters: radiusMeters,
            styleKey: styleKey,
            urlTemplate: urlTemplate,
          );
      _refresh();
      state = state.copyWith(downloading: false, clearProgress: true);
    } catch (e) {
      state = state.copyWith(
        downloading: false,
        error: e.toString(),
        clearProgress: true,
      );
      _refresh();
    }
  }

  void cancel() {
    ref.read(tileCacheServiceProvider).cancelDownload();
  }

  Future<void> delete(String id) async {
    await ref.read(tileCacheServiceProvider).deleteRegion(id);
    _refresh();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final offlineProvider =
    StateNotifierProvider<OfflineNotifier, OfflineState>((ref) {
  return OfflineNotifier(ref);
});

final trackRecorderProvider = Provider<TrackRecorder>((ref) => TrackRecorder());

final isRecordingProvider = StateProvider<bool>((ref) => false);
