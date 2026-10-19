import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/core/map_style.dart';
import 'package:navigation/models/app_settings.dart';

void main() {
  ResolvedMapStyle resolve(
    AppSettings s, {
    Brightness b = Brightness.light,
    bool night = false,
  }) => resolveMapStyle(settings: s, platform: b, nightDriving: night);

  test('without a CARTO key street maps use keyless OSM tiles', () {
    final light = resolve(const AppSettings());
    expect(light.urlTemplate, contains('tile.openstreetmap.org'));
    expect(light.urlTemplate, isNot(contains('cartocdn')));
    expect(light.invertTiles, isFalse);

    final dark = resolve(const AppSettings(), b: Brightness.dark);
    expect(dark.urlTemplate, contains('tile.openstreetmap.org'));
    expect(dark.dark, isTrue);
    expect(dark.invertTiles, isTrue);

    final night = resolve(const AppSettings(), night: true);
    expect(night.invertTiles, isTrue);
  });

  test('with a CARTO key street maps use CARTO with ?key=', () {
    const s = AppSettings(
      mapStyle: MapStylePreference.dark,
      cartoApiKey: 'abc 123',
    );
    final dark = resolve(s);
    expect(dark.urlTemplate, contains('cartocdn.com/dark_all'));
    expect(dark.urlTemplate, endsWith('.png?key=abc+123'));
    expect(dark.invertTiles, isFalse);
    final light = resolve(s.copyWith(mapStyle: MapStylePreference.light));
    expect(light.urlTemplate, contains('rastertiles/voyager'));
  });

  test('OSM tiles may not be bulk downloaded; others may', () {
    expect(
      tileSourceAllowsBulkDownload(resolve(const AppSettings()).urlTemplate),
      isFalse,
    );
    expect(
      tileSourceAllowsBulkDownload(
        resolve(const AppSettings(cartoApiKey: 'k')).urlTemplate,
      ),
      isTrue,
    );
  });

  test('cartoApiKey round-trips through JSON', () {
    const s = AppSettings(cartoApiKey: 'xyz');
    expect(AppSettings.fromJson(s.toJson()).cartoApiKey, 'xyz');
    expect(AppSettings.fromJson(const {}).cartoApiKey, '');
  });
}
