import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/models/app_settings.dart';
import 'package:navigation/models/camera_view.dart';
import 'package:navigation/models/place.dart';
import 'package:navigation/models/route_plan.dart';
import 'package:navigation/services/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('AppSettings round-trip JSON', () {
    const s = AppSettings(
      theme: ThemePreference.dark,
      mapStyle: MapStylePreference.topo,
      metricUnits: false,
      courseUp: false,
      voiceEnabled: false,
      nightDriving: NightDriving.on,
      customRoutingUrl: 'http://127.0.0.1:5000',
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.theme, ThemePreference.dark);
    expect(back.mapStyle, MapStylePreference.topo);
    expect(back.metricUnits, false);
    expect(back.courseUp, false);
    expect(back.voiceEnabled, false);
    expect(back.nightDriving, NightDriving.on);
    expect(back.customRoutingUrl, 'http://127.0.0.1:5000');
    expect(back.followOnStart, isTrue);
  });

  test('Place JSON round-trip with role and group', () {
    const p = Place(
      id: 'x',
      name: 'Berlin',
      latitude: 52.5,
      longitude: 13.4,
      subtitle: 'Germany',
      group: 'Cafes',
      role: PlaceRole.home,
    );
    final back = Place.fromJson(p.toJson());
    expect(back.name, 'Berlin');
    expect(back.latitude, 52.5);
    expect(back.subtitle, 'Germany');
    expect(back.group, 'Cafes');
    expect(back.role, PlaceRole.home);
  });

  test('RoutePlan format helpers', () {
    const plan = RoutePlan(
      origin: Place(id: 'a', name: 'A', latitude: 0, longitude: 0),
      destination: Place(id: 'b', name: 'B', latitude: 1, longitude: 1),
      mode: TravelMode.bike,
      geometry: [],
      distanceMeters: 1500,
      durationSeconds: 900,
      instructions: [],
    );
    expect(plan.formatDistance(metric: true), contains('km'));
    expect(plan.formatDuration(), contains('min'));
  });

  test('saveCamera then loadCamera round-trips lat/lng/zoom/rotation', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs);
    const view = CameraView(
      latitude: 48.8566,
      longitude: 2.3522,
      zoom: 16.25,
      rotation: 12.0,
    );
    await repo.saveCamera(view);
    final back = repo.loadCamera();
    expect(back, isNotNull);
    expect(back!.latitude, 48.8566);
    expect(back.longitude, 2.3522);
    expect(back.zoom, 16.25);
    expect(back.rotation, 12.0);
    expect(back.latitude, isNot(52.52));
    expect(back.zoom, isNot(14.0));
  });

  test('empty prefs => loadCamera() is null', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs);
    expect(repo.loadCamera(), isNull);
  });
}
