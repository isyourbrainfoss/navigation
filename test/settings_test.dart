import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/models/app_settings.dart';
import 'package:navigation/models/place.dart';
import 'package:navigation/models/route_plan.dart';

void main() {
  test('AppSettings round-trip JSON', () {
    const s = AppSettings(
      theme: ThemePreference.dark,
      mapStyle: MapStylePreference.light,
      metricUnits: false,
      courseUp: false,
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.theme, ThemePreference.dark);
    expect(back.mapStyle, MapStylePreference.light);
    expect(back.metricUnits, false);
    expect(back.courseUp, false);
  });

  test('Place JSON round-trip', () {
    const p = Place(
      id: 'x',
      name: 'Berlin',
      latitude: 52.5,
      longitude: 13.4,
      subtitle: 'Germany',
    );
    final back = Place.fromJson(p.toJson());
    expect(back.name, 'Berlin');
    expect(back.latitude, 52.5);
    expect(back.subtitle, 'Germany');
  });

  test('RoutePlan format helpers', () {
    const plan = RoutePlan(
      origin: Place(id: 'a', name: 'A', latitude: 0, longitude: 0),
      destination: Place(id: 'b', name: 'B', latitude: 1, longitude: 1),
      mode: TravelMode.walk,
      geometry: [],
      distanceMeters: 1500,
      durationSeconds: 900,
      instructions: [],
    );
    expect(plan.formatDistance(metric: true), contains('km'));
    expect(plan.formatDuration(), contains('min'));
  });
}
