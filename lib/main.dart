import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'models/place.dart';
import 'providers/app_providers.dart';
import 'services/favorites_repository.dart';
import 'services/keep_awake_service.dart';
import 'services/location_service.dart';
import 'services/routing_service.dart';
import 'services/search_service.dart';
import 'services/settings_repository.dart';
import 'services/tile_cache_service.dart';
import 'services/track_repository.dart';
import 'services/voice_service.dart';

Place? parseLaunchPlace(List<String> args) {
  for (final a in args) {
    final place = SearchService().parseCoordinates(a);
    if (place != null) return place;
  }
  return null;
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsRepo = await SettingsRepository.create();
  final favoritesRepo = await FavoritesRepository.create();
  final tracksRepo = await TrackRepository.create();
  final location = LocationService();
  final search = SearchService();
  final routing = RoutingService();
  final tiles = TileCacheService();
  final voice = VoiceService();
  final keepAwake = KeepAwakeService();
  await tiles.init();

  // Kick off permission + first fix without blocking first frame.
  // ignore: unawaited_futures
  location.ensurePermission().then((_) => location.start());

  final launchPlace = parseLaunchPlace(args);

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        favoritesRepositoryProvider.overrideWithValue(favoritesRepo),
        trackRepositoryProvider.overrideWithValue(tracksRepo),
        locationServiceProvider.overrideWithValue(location),
        searchServiceProvider.overrideWithValue(search),
        routingServiceProvider.overrideWithValue(routing),
        tileCacheServiceProvider.overrideWithValue(tiles),
        voiceServiceProvider.overrideWithValue(voice),
        keepAwakeServiceProvider.overrideWithValue(keepAwake),
        initialDestinationProvider.overrideWith((ref) => launchPlace),
      ],
      child: const NavigationApp(),
    ),
  );
}
