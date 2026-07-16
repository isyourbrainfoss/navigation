import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_settings.dart';
import '../models/offline_region.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import '../services/favorites_repository.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/search_service.dart';
import '../services/settings_repository.dart';
import '../services/tile_cache_service.dart';

// --- Injected at startup ---

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

// --- Favorites / recents (reloadable) ---

final favoritesListProvider = StateProvider<List<Place>>((ref) {
  return ref.watch(favoritesRepositoryProvider).loadFavorites();
});

final recentsListProvider = StateProvider<List<Place>>((ref) {
  return ref.watch(favoritesRepositoryProvider).loadRecents();
});

// --- Settings ---

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
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo, repo.load());
});

// --- Location ---

final locationFixProvider = StreamProvider<LocationFix?>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.fixes.map<LocationFix?>((f) => f);
});

final locationPermissionProvider =
    StateProvider<LocationPermissionState>((ref) {
  return ref.watch(locationServiceProvider).permissionState;
});

// --- Map session state ---

enum NavPhase { browsing, preview, navigating, arrived }

class MapSession {
  const MapSession({
    this.phase = NavPhase.browsing,
    this.destination,
    this.mode = TravelMode.walk,
    this.route,
    this.routeError,
    this.routing = false,
    this.followUser = true,
    this.instructionIndex = 0,
    this.pin,
  });

  final NavPhase phase;
  final Place? destination;
  final TravelMode mode;
  final RoutePlan? route;
  final String? routeError;
  final bool routing;
  final bool followUser;
  final int instructionIndex;
  final Place? pin;

  MapSession copyWith({
    NavPhase? phase,
    Place? destination,
    bool clearDestination = false,
    TravelMode? mode,
    RoutePlan? route,
    bool clearRoute = false,
    String? routeError,
    bool clearRouteError = false,
    bool? routing,
    bool? followUser,
    int? instructionIndex,
    Place? pin,
    bool clearPin = false,
  }) {
    return MapSession(
      phase: phase ?? this.phase,
      destination:
          clearDestination ? null : (destination ?? this.destination),
      mode: mode ?? this.mode,
      route: clearRoute ? null : (route ?? this.route),
      routeError: clearRouteError ? null : (routeError ?? this.routeError),
      routing: routing ?? this.routing,
      followUser: followUser ?? this.followUser,
      instructionIndex: instructionIndex ?? this.instructionIndex,
      pin: clearPin ? null : (pin ?? this.pin),
    );
  }
}

class MapSessionNotifier extends StateNotifier<MapSession> {
  MapSessionNotifier(this.ref) : super(const MapSession());

  final Ref ref;

  void setFollowUser(bool v) => state = state.copyWith(followUser: v);

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

  Future<void> selectDestination(Place place) async {
    final favs = ref.read(favoritesRepositoryProvider);
    await favs.addRecent(place);
    ref.read(recentsListProvider.notifier).state = favs.loadRecents();
    state = state.copyWith(
      destination: place,
      phase: NavPhase.preview,
      clearRoute: true,
      clearRouteError: true,
      clearPin: true,
    );
    await computeRoute();
  }

  Future<void> computeRoute() async {
    final dest = state.destination;
    if (dest == null) return;

    final location = ref.read(locationServiceProvider);
    var originFix = location.lastFix;
    originFix ??= await location.getCurrent();

    // Fallback origin: last map bias or Berlin if nothing available.
    final originLl = originFix?.position ?? const LatLng(52.52, 13.405);
    final origin = Place.fromLatLng(originLl, name: 'Current location');

    state = state.copyWith(routing: true, clearRouteError: true);
    try {
      final plan = await ref.read(routingServiceProvider).route(
            origin: origin,
            destination: dest,
            mode: state.mode,
          );
      state = state.copyWith(
        route: plan,
        routing: false,
        phase: NavPhase.preview,
        instructionIndex: 0,
      );
    } catch (e) {
      state = state.copyWith(
        routing: false,
        routeError: e.toString(),
        clearRoute: true,
      );
    }
  }

  void startNavigation() {
    if (state.route == null) return;
    state = state.copyWith(
      phase: NavPhase.navigating,
      followUser: true,
      instructionIndex: 0,
    );
  }

  void stopNavigation() {
    state = state.copyWith(
      phase: NavPhase.browsing,
      clearRoute: true,
      clearDestination: true,
      clearRouteError: true,
      instructionIndex: 0,
    );
  }

  void setInstructionIndex(int i) {
    state = state.copyWith(instructionIndex: i);
  }

  void markArrived() {
    state = state.copyWith(phase: NavPhase.arrived, followUser: false);
  }

  void clearArrived() {
    state = state.copyWith(
      phase: NavPhase.browsing,
      clearRoute: true,
      clearDestination: true,
    );
  }
}

final mapSessionProvider =
    StateNotifierProvider<MapSessionNotifier, MapSession>((ref) {
  return MapSessionNotifier(ref);
});

// --- Search ---

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.loading = false,
    this.error,
  });

  final String query;
  final List<Place> results;
  final bool loading;
  final String? error;

  SearchState copyWith({
    String? query,
    List<Place>? results,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this.ref) : super(const SearchState());

  final Ref ref;

  Future<void> search(String query, {LatLng? bias}) async {
    state = state.copyWith(query: query, loading: true, clearError: true);
    if (query.trim().isEmpty) {
      state = state.copyWith(results: [], loading: false);
      return;
    }
    try {
      final results = await ref.read(searchServiceProvider).search(
            query,
            bias: bias,
          );
      // Ignore stale responses.
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

  void clear() => state = const SearchState();
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

// --- Offline downloads ---

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
