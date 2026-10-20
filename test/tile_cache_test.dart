import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:navigation/core/constants.dart';
import 'package:navigation/core/geometry.dart';
import 'package:navigation/core/map_style.dart';
import 'package:navigation/models/app_settings.dart';
import 'package:navigation/models/offline_region.dart';
import 'package:navigation/services/tile_cache_service.dart';
import 'package:path/path.dart' as p;

List<int> fixture(String name) =>
    File(p.join('test', 'fixtures', name)).readAsBytesSync();

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('nav_tiles_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('CARTO "API KEY REQUIRED" placeholder', () {
    test('both placeholder tiles are recognised; real tiles are not', () {
      expect(
        isCartoPlaceholderTile(fixture('carto_placeholder_light.png')),
        isTrue,
      );
      expect(
        isCartoPlaceholderTile(fixture('carto_placeholder_dark.png')),
        isTrue,
      );
      final other = List<int>.of(fixture('carto_placeholder_light.png'));
      other[100] ^= 0xff; // same size, different bytes
      expect(isCartoPlaceholderTile(other), isFalse);
      expect(isCartoPlaceholderTile(List.filled(1234, 7)), isFalse);
    });

    test(
      'writeTile refuses placeholders; findTile drops cached ones',
      () async {
        final svc = TileCacheService(
          client: MockClient((_) async {
            return http.Response('', 404);
          }),
        );
        await svc.init(rootOverride: tmp);
        await svc.writeTile(
          cartoLightStyleKey,
          5,
          16,
          10,
          fixture('carto_placeholder_light.png'),
        );
        expect(
          svc.tileFile(cartoLightStyleKey, 5, 16, 10).existsSync(),
          isFalse,
        );

        // A placeholder that slipped into the cache earlier is purged on read.
        final f = svc.tileFile('osm', 5, 16, 10)
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(fixture('carto_placeholder_dark.png'));
        expect(await svc.findTile('osm', 5, 16, 10), isNull);
        expect(f.existsSync(), isFalse);

        await svc.writeTile('osm', 5, 16, 10, [1, 2, 3]);
        expect(await svc.findTile('osm', 5, 16, 10), isNotNull);
      },
    );
  });

  test('legacy light/dark cache dirs are purged once', () async {
    for (final k in ['light', 'dark', 'topo']) {
      File(p.join(tmp.path, k, '1', '0', '0.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);
    }
    final svc = TileCacheService();
    await svc.init(rootOverride: tmp);
    expect(Directory(p.join(tmp.path, 'light')).existsSync(), isFalse);
    expect(Directory(p.join(tmp.path, 'dark')).existsSync(), isFalse);
    expect(Directory(p.join(tmp.path, 'topo')).existsSync(), isTrue);
    expect(
      File(
        p.join(tmp.path, TileCacheService.legacyCartoPurgeMarker),
      ).existsSync(),
      isTrue,
    );

    // Second start: marker present, nothing is deleted any more.
    File(p.join(tmp.path, 'light', '1', '0', '0.png'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    await TileCacheService().init(rootOverride: tmp);
    expect(Directory(p.join(tmp.path, 'light')).existsSync(), isTrue);
  });

  test('keyed CARTO uses new cache keys, not the legacy light/dark', () {
    ResolvedMapStyle r(MapStylePreference s) => resolveMapStyle(
      settings: AppSettings(mapStyle: s, cartoApiKey: 'k'),
      platform: Brightness.light,
      nightDriving: false,
    );
    expect(r(MapStylePreference.light).styleKey, cartoLightStyleKey);
    expect(r(MapStylePreference.dark).styleKey, cartoDarkStyleKey);
    expect(legacyCartoStyleKeys, isNot(contains(cartoLightStyleKey)));
    expect(legacyCartoStyleKeys, isNot(contains(cartoDarkStyleKey)));
  });

  test('bulk download allowlist: keyed CARTO only', () {
    const keyed = '${AppConstants.tileUrlLight}?key=abc';
    expect(tileSourceAllowsBulkDownload(keyed), isTrue);
    expect(
      tileSourceAllowsBulkDownload('${AppConstants.tileUrlDark}?key=x'),
      isTrue,
    );
    expect(tileSourceAllowsBulkDownload(AppConstants.tileUrlLight), isFalse);
    expect(tileSourceAllowsBulkDownload(AppConstants.tileUrlOsm), isFalse);
    expect(tileSourceAllowsBulkDownload(AppConstants.tileUrlTopo), isFalse);
    expect(tileSourceAllowsBulkDownload(AppConstants.tileUrlCycle), isFalse);
    expect(
      tileSourceAllowsBulkDownload(
        'https://basemaps.cartocdn.com.evil.example/{z}/{x}/{y}.png?key=k',
      ),
      isFalse,
    );
  });

  test('downloadRegion rejects non-allowlisted sources', () async {
    var requests = 0;
    final svc = TileCacheService(
      client: MockClient((_) async {
        requests++;
        return http.Response('', 200);
      }),
    );
    await svc.init(rootOverride: tmp);
    for (final url in [
      AppConstants.tileUrlOsm,
      AppConstants.tileUrlTopo,
      AppConstants.tileUrlCycle,
    ]) {
      await expectLater(
        svc.downloadRegion(
          name: 'x',
          center: const LatLng(59.9, 10.7),
          radiusMeters: 500,
          styleKey: 'osm',
          urlTemplate: url,
          minZoom: 10,
          maxZoom: 10,
        ),
        throwsStateError,
      );
    }
    expect(requests, 0);
  });

  test('download stops and fails on CARTO placeholder (bad key)', () async {
    var requests = 0;
    final placeholder = fixture('carto_placeholder_light.png');
    final svc = TileCacheService(
      client: MockClient((_) async {
        requests++;
        return http.Response.bytes(placeholder, 200);
      }),
    );
    await svc.init(rootOverride: tmp);
    await expectLater(
      svc.downloadRegion(
        name: 'x',
        center: const LatLng(59.9, 10.7),
        radiusMeters: 3000,
        styleKey: cartoLightStyleKey,
        urlTemplate: '${AppConstants.tileUrlLight}?key=bad',
        minZoom: 12,
        maxZoom: 13,
      ),
      throwsStateError,
    );
    expect(requests, lessThanOrEqualTo(AppConstants.tileDownloadConcurrency));
    expect(svc.regions.first.status, DownloadStatus.failed);
    expect(
      Directory(p.join(tmp.path, cartoLightStyleKey)).existsSync(),
      isFalse,
    );
  });

  test('deleteRegion also removes osm and carto-* tiles', () async {
    final svc = TileCacheService();
    await svc.init(rootOverride: tmp);
    final region = OfflineRegion(
      id: 'r1',
      name: 'r',
      centerLat: 59.9,
      centerLon: 10.7,
      radiusMeters: 3000,
      minZoom: 12,
      maxZoom: 12,
      createdAtMs: 0,
    );
    File(
      p.join(tmp.path, 'regions.json'),
    ).writeAsStringSync(jsonEncode([region.toJson()]));
    await svc.init(rootOverride: tmp);
    final t = GeoMath.tilesForCircle(
      center: region.center,
      radiusMeters: region.radiusMeters,
      z: 12,
    ).first;
    final (z, x, y) = (t.z, t.x, t.y);
    for (final k in ['osm', cartoLightStyleKey, cartoDarkStyleKey]) {
      svc.tileFile(k, z, x, y)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync([1]);
    }
    await svc.deleteRegion('r1');
    for (final k in ['osm', cartoLightStyleKey, cartoDarkStyleKey]) {
      expect(svc.tileFile(k, z, x, y).existsSync(), isFalse, reason: k);
    }
  });

  test('redactTileKey hides CARTO keys in log text', () {
    expect(
      redactTileKey(
        'ClientException: x, uri=https://basemaps.cartocdn.com/'
        'dark_all/1/2/3.png?key=s3cr3t+k&x=1',
      ),
      'ClientException: x, uri=https://basemaps.cartocdn.com/'
      'dark_all/1/2/3.png?key=<redacted>&x=1',
    );
    expect(redactTileKey('no key here'), 'no key here');
  });
}
