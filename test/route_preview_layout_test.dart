import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navigation/features/map/map_screen.dart';
import 'package:navigation/features/navigate/route_preview_sheet.dart';
import 'package:navigation/models/place.dart';
import 'package:navigation/models/route_plan.dart';
import 'package:navigation/providers/app_providers.dart';
import 'package:navigation/services/favorites_repository.dart';
import 'package:navigation/services/keep_awake_service.dart';
import 'package:navigation/services/location_service.dart';
import 'package:navigation/services/routing_service.dart';
import 'package:navigation/services/search_service.dart';
import 'package:navigation/services/settings_repository.dart';
import 'package:navigation/services/tile_cache_service.dart';
import 'package:navigation/services/track_repository.dart';
import 'package:navigation/services/voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestLocation extends LocationService {
  @override
  Future<LocationPermissionState> ensurePermission() async {
    permissionState = LocationPermissionState.granted;
    return permissionState;
  }

  @override
  Future<void> start({bool navigating = false}) async {}

  @override
  Future<LocationFix?> getCurrent() async => null;
}

void main() {
  testWidgets('route preview sheet bottom matches the map stack bottom',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      SettingsRepository.locationIntroKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final settingsRepo = SettingsRepository(prefs);
    final favoritesRepo = FavoritesRepository(prefs);
    final tracksRepo = TrackRepository(prefs);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          favoritesRepositoryProvider.overrideWithValue(favoritesRepo),
          trackRepositoryProvider.overrideWithValue(tracksRepo),
          locationServiceProvider.overrideWithValue(_TestLocation()),
          searchServiceProvider.overrideWithValue(SearchService()),
          routingServiceProvider.overrideWithValue(RoutingService()),
          tileCacheServiceProvider.overrideWithValue(TileCacheService()),
          voiceServiceProvider.overrideWithValue(VoiceService()),
          keepAwakeServiceProvider.overrideWithValue(KeepAwakeService()),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    const dest = Place(
      id: 'dest',
      name: 'Test destination',
      latitude: 52.52,
      longitude: 13.405,
    );
    const origin = Place(
      id: 'origin',
      name: 'Here',
      latitude: 52.51,
      longitude: 13.40,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapScreen)),
    );
    container.read(mapSessionProvider.notifier).seed(
          MapSession(
            phase: NavPhase.preview,
            destination: dest,
            route: RoutePlan(
              origin: origin,
              destination: dest,
              mode: TravelMode.drive,
              geometry: const [
                LatLng(52.51, 13.40),
                LatLng(52.52, 13.405),
              ],
              distanceMeters: 1400,
              durationSeconds: 180,
              instructions: const [],
            ),
          ),
        );
    await tester.pump();

    expect(find.byType(RoutePreviewBar), findsOneWidget);
    expect(find.text('Go'), findsOneWidget);

    final sheet = tester.getRect(
      find
          .descendant(
            of: find.byType(RoutePreviewBar),
            matching: find.byType(Material),
          )
          .first,
    );
    final stack = tester.getRect(
      find
          .ancestor(
            of: find.byType(RoutePreviewBar),
            matching: find.byType(Stack),
          )
          .first,
    );

    expect(sheet.bottom, closeTo(stack.bottom, 1));
    expect(
      sheet.top,
      greaterThan(stack.top + stack.height * (1 - RoutePreviewBar.peekSize - 0.08)),
    );
    expect(sheet.height, closeTo(stack.height * RoutePreviewBar.peekSize, 24));
  });
}
