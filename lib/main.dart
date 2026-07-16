import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/app_providers.dart';
import 'services/favorites_repository.dart';
import 'services/location_service.dart';
import 'services/routing_service.dart';
import 'services/search_service.dart';
import 'services/settings_repository.dart';
import 'services/tile_cache_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsRepo = await SettingsRepository.create();
  final favoritesRepo = await FavoritesRepository.create();
  final location = LocationService();
  final search = SearchService();
  final routing = RoutingService();
  final tiles = TileCacheService();
  await tiles.init();

  // Kick off permission + first fix without blocking first frame.
  // ignore: unawaited_futures
  location.ensurePermission().then((_) => location.start());

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        favoritesRepositoryProvider.overrideWithValue(favoritesRepo),
        locationServiceProvider.overrideWithValue(location),
        searchServiceProvider.overrideWithValue(search),
        routingServiceProvider.overrideWithValue(routing),
        tileCacheServiceProvider.overrideWithValue(tiles),
      ],
      child: const NavigationApp(),
    ),
  );
}
