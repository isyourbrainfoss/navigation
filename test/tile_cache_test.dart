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

  group('stale tile refresh', () {
    test('tiles older than 7 days are stale; fresh ones are not', () async {
      final svc = TileCacheService(
        client: MockClient((_) async {
          return http.Response('', 404);
        }),
      );
      await svc.init(rootOverride: tmp);
      await svc.writeTile('osm', 5, 16, 10, [1, 2, 3]);
      final f = (await svc.findTile('osm', 5, 16, 10))!;
      expect(await svc.isTileStale(f), isFalse);
      f.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 8)));
      expect(await svc.isTileStale(f), isTrue);
      // Reading a tile must not reset its age, or it would never refresh.
      await svc.findTile('osm', 5, 16, 10);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await svc.isTileStale(f), isTrue);
    });

    test(
      'refreshTile replaces the file on success, keeps it on failure',
      () async {
        var ok = false;
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return ok
              ? http.Response.bytes([9, 9, 9], 200)
              : http.Response('', 503);
        });
        final svc = TileCacheService(client: client);
        await svc.init(rootOverride: tmp);
        await svc.writeTile('osm', 5, 16, 10, [1, 2, 3]);
        final f = svc.tileFile('osm', 5, 16, 10)
          ..setLastModifiedSync(
            DateTime.now().subtract(const Duration(days: 30)),
          );

        expect(
          await svc.refreshTile('osm', 5, 16, 10, 'https://t/5/16/10', client),
          isFalse,
        );
        expect(f.readAsBytesSync(), [1, 2, 3]);
        expect(await svc.isTileStale(f), isTrue);
        expect(svc.tilesFailing.value, isFalse);

        ok = true;
        expect(
          await svc.refreshTile('osm', 5, 16, 10, 'https://t/5/16/10', client),
          isTrue,
        );
        expect(f.readAsBytesSync(), [9, 9, 9]);
        expect(await svc.isTileStale(f), isFalse);
        expect(calls, 2);
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

  group('cache writes', () {
    test('writeTile and regions.json leave no temp files behind', () async {
      final svc = TileCacheService(
        client: MockClient((_) async => http.Response('', 404)),
      );
      await svc.init(rootOverride: tmp);
      await svc.writeTile('osm', 3, 1, 2, [1, 2, 3]);
      expect(await svc.tileFile('osm', 3, 1, 2).readAsBytes(), [1, 2, 3]);
      await svc.writeTile('osm', 3, 1, 2, [4, 5]);
      expect(await svc.tileFile('osm', 3, 1, 2).readAsBytes(), [4, 5]);
      final leftovers = tmp
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    });
  });

  group('cache limit', () {
    void put(TileCacheService svc, String style, int z, int x, int y,
        int size, DateTime modified) {
      svc.tileFile(style, z, x, y)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(List.filled(size, 1))
        ..setLastModifiedSync(modified);
    }

    test('no-op under the cap or with no limit', () async {
      final svc = TileCacheService();
      await svc.init(rootOverride: tmp);
      put(svc, 'osm', 10, 1, 1, 1000, DateTime(2026));
      expect((await svc.trimToCap(maxBytes: 5000)).removedTiles, 0);
      expect((await svc.trimToCap(maxBytes: 0)).removedTiles, 0);
      expect(svc.tileFile('osm', 10, 1, 1).existsSync(), isTrue);
      final usage = await svc.cacheUsage();
      expect(usage.bytes, 1000);
      expect(usage.tiles, 1);
    });

    test('evicts least recently used browsed tiles to 90 % of the cap',
        () async {
      final svc = TileCacheService();
      await svc.init(rootOverride: tmp);
      for (var i = 0; i < 10; i++) {
        put(svc, 'osm', 10, i, 0, 1000, DateTime(2026, 1, 1 + i));
      }
      final r = await svc.trimToCap(maxBytes: 6000);
      // 10 000 bytes -> at most 5 400: the five oldest go.
      expect(r.removedTiles, 5);
      expect(r.freedBytes, 5000);
      for (var i = 0; i < 10; i++) {
        expect(svc.tileFile('osm', 10, i, 0).existsSync(), i >= 5,
            reason: 'tile $i');
      }
    });

    test('never evicts tiles inside a saved offline region', () async {
      final region = OfflineRegion(
        id: 'r1',
        name: 'Lørenskog',
        centerLat: 59.93,
        centerLon: 10.95,
        radiusMeters: 500,
        minZoom: 14,
        maxZoom: 14,
        createdAtMs: 0,
      );
      File(p.join(tmp.path, 'regions.json'))
          .writeAsStringSync(jsonEncode([region.toJson()]));
      final svc = TileCacheService();
      await svc.init(rootOverride: tmp);
      final inRegion = GeoMath.tilesForCircle(
        center: region.center,
        radiusMeters: region.radiusMeters,
        z: 14,
      ).first;
      // The region tile is the oldest file, yet it must survive.
      put(svc, cartoLightStyleKey, inRegion.z, inRegion.x, inRegion.y, 4000,
          DateTime(2020));
      put(svc, 'osm', 5, 1, 1, 4000, DateTime(2026));
      put(svc, 'osm', 5, 2, 1, 4000, DateTime(2026, 2));
      await svc.trimToCap(maxBytes: 9000);
      expect(
        svc
            .tileFile(cartoLightStyleKey, inRegion.z, inRegion.x, inRegion.y)
            .existsSync(),
        isTrue,
      );
      expect(svc.tileFile('osm', 5, 1, 1).existsSync(), isFalse);
      expect(svc.tileFile('osm', 5, 2, 1).existsSync(), isTrue);
    });

    test(
      'clearBrowsedTiles drops all browsed tiles, keeps region tiles',
      () async {
        final region = OfflineRegion(
          id: 'r1',
          name: 'Lørenskog',
          centerLat: 59.93,
          centerLon: 10.95,
          radiusMeters: 500,
          minZoom: 14,
          maxZoom: 14,
          createdAtMs: 0,
        );
        File(
          p.join(tmp.path, 'regions.json'),
        ).writeAsStringSync(jsonEncode([region.toJson()]));
        final svc = TileCacheService();
        await svc.init(rootOverride: tmp);
        final inRegion = GeoMath.tilesForCircle(
          center: region.center,
          radiusMeters: region.radiusMeters,
          z: 14,
        ).first;
        put(
          svc,
          cartoLightStyleKey,
          inRegion.z,
          inRegion.x,
          inRegion.y,
          4000,
          DateTime(2020),
        );
        put(svc, 'osm', 5, 1, 1, 4000, DateTime(2026));
        put(svc, 'osm', 5, 2, 1, 4000, DateTime(2026, 2));
        final r = await svc.clearBrowsedTiles();
        expect(r.removedTiles, 2);
        expect(r.freedBytes, 8000);
        expect(
          svc
              .tileFile(cartoLightStyleKey, inRegion.z, inRegion.x, inRegion.y)
              .existsSync(),
          isTrue,
        );
        expect(svc.tileFile('osm', 5, 1, 1).existsSync(), isFalse);
        expect(svc.tileFile('osm', 5, 2, 1).existsSync(), isFalse);
      },
    );
  });

  test('tilesFailing flips after repeated failures and clears on success',
      () {
    final svc = TileCacheService();
    for (var i = 0; i < TileCacheService.tileFailuresBeforeBanner - 1; i++) {
      svc.reportTileFetch(ok: false);
    }
    expect(svc.tilesFailing.value, isFalse);
    svc.reportTileFetch(ok: false);
    expect(svc.tilesFailing.value, isTrue);
    svc.reportTileFetch(ok: true);
    expect(svc.tilesFailing.value, isFalse);
  });
}
