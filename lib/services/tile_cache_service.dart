import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/geometry.dart';
import '../core/map_style.dart';
import '../models/offline_region.dart';

/// File-tree offline tile cache + region bulk download.
class TileCacheService {
  TileCacheService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  Directory? _root;
  final List<OfflineRegion> regions = [];
  final _progressController = StreamController<DownloadProgress>.broadcast();
  bool _cancelRequested = false;
  bool _downloading = false;

  /// Without a timeout a stalled connection kept a tile (or an offline
  /// download worker, which cancel cannot interrupt) waiting indefinitely.
  static const tileRequestTimeout = Duration(seconds: 20);

  Stream<DownloadProgress> get progress => _progressController.stream;
  bool get isDownloading => _downloading;

  /// True while map tiles keep failing to load from the network (offline,
  /// DNS, server refusing us). The map shows a banner instead of silently
  /// rendering blank squares. Cleared by the next successful fetch.
  final ValueNotifier<bool> tilesFailing = ValueNotifier(false);
  int _consecutiveTileFailures = 0;

  /// Failures in a row before [tilesFailing] flips; a single slow tile is
  /// not worth a banner.
  static const tileFailuresBeforeBanner = 4;

  @visibleForTesting
  void reportTileFetch({required bool ok}) {
    if (ok) {
      _consecutiveTileFailures = 0;
      if (tilesFailing.value) tilesFailing.value = false;
    } else {
      _consecutiveTileFailures++;
      if (_consecutiveTileFailures >= tileFailuresBeforeBanner &&
          !tilesFailing.value) {
        tilesFailing.value = true;
      }
    }
  }

  /// Soft cap for tiles cached while browsing, in bytes; 0 = no limit.
  /// Tiles inside saved offline regions never count against eviction: only
  /// the least recently used browsed tiles are removed, and only once the
  /// cache is over the cap.
  int maxCacheBytes = defaultMaxCacheBytes;
  static const defaultMaxCacheBytes = 500 * 1024 * 1024;
  static const _trimEveryWrites = 300;
  int _writesSinceTrim = 0;
  Future<CacheTrimResult>? _trimming;

  /// [rootOverride] is for tests; the app uses the support directory.
  Future<void> init({Directory? rootOverride}) async {
    if (rootOverride != null) {
      _root = rootOverride;
    } else {
      final support = await getApplicationSupportDirectory();
      _root = Directory(p.join(support.path, 'offline_tiles'));
    }
    await _root!.create(recursive: true);
    await _purgeLegacyCartoTilesOnce();
    await _loadRegionsMeta();
  }

  /// Bytes and tile count currently in the cache (all styles).
  Future<({int bytes, int tiles})> cacheUsage() async {
    if (_root == null) return (bytes: 0, tiles: 0);
    var bytes = 0;
    var tiles = 0;
    for (final f in await _tileFiles()) {
      bytes += f.size;
      tiles++;
    }
    return (bytes: bytes, tiles: tiles);
  }

  Future<List<({File file, int size, DateTime modified, String key})>>
      _tileFiles() async {
    final out = <({File file, int size, DateTime modified, String key})>[];
    for (final style in allTileStyleKeys) {
      final dir = Directory(p.join(root.path, style));
      if (!await dir.exists()) continue;
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is! File || !e.path.endsWith('.png')) continue;
        try {
          final st = await e.stat();
          final rel = p.split(p.relative(e.path, from: dir.path));
          if (rel.length != 3) continue;
          final key = '${rel[0]}/${rel[1]}/${p.basenameWithoutExtension(rel[2])}';
          out.add((file: e, size: st.size, modified: st.modified, key: key));
        } catch (_) {}
      }
    }
    return out;
  }

  Set<String> _regionTileKeys() {
    final keys = <String>{};
    for (final r in regions) {
      for (var z = r.minZoom; z <= r.maxZoom; z++) {
        for (final t in GeoMath.tilesForCircle(
          center: r.center,
          radiusMeters: r.radiusMeters,
          z: z,
        )) {
          keys.add('${t.z}/${t.x}/${t.y}');
        }
      }
    }
    return keys;
  }

  /// Evict least-recently-used browsed tiles until the cache is at 90 % of
  /// [maxBytes] (default [maxCacheBytes]). No-op when under the cap or when
  /// the cap is 0. Tiles inside saved offline regions are never evicted.
  Future<CacheTrimResult> trimToCap({int? maxBytes}) {
    return _trimming ??= _trim(maxBytes ?? maxCacheBytes).whenComplete(() {
      _trimming = null;
    });
  }

  Future<CacheTrimResult> _trim(int cap) async {
    if (_root == null || cap <= 0) return const CacheTrimResult(0, 0);
    final files = await _tileFiles();
    var total = files.fold<int>(0, (a, f) => a + f.size);
    if (total <= cap) return const CacheTrimResult(0, 0);
    final protected = _regionTileKeys();
    final candidates = files.where((f) => !protected.contains(f.key)).toList()
      ..sort((a, b) => a.modified.compareTo(b.modified));
    final target = (cap * 0.9).floor();
    var removed = 0;
    var freed = 0;
    for (final f in candidates) {
      if (total <= target) break;
      try {
        await f.file.delete();
        total -= f.size;
        freed += f.size;
        removed++;
      } catch (_) {}
    }
    return CacheTrimResult(removed, freed);
  }

  /// Marker written once the legacy `light` / `dark` dirs have been purged.
  static const legacyCartoPurgeMarker = '.purged_keyless_carto_v1';

  /// Before CARTO needed a key, Voyager / Dark Matter tiles were cached under
  /// `light` / `dark`. Since 25 Sep 2026 keyless requests return HTTP 200
  /// "API KEY REQUIRED" placeholders, which were cached there too. Keyed
  /// CARTO now uses fresh keys, and the old dirs are deleted once.
  Future<void> _purgeLegacyCartoTilesOnce() async {
    final marker = File(p.join(root.path, legacyCartoPurgeMarker));
    if (await marker.exists()) return;
    for (final key in legacyCartoStyleKeys) {
      final dir = Directory(p.join(root.path, key));
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (e) {
        debugPrint('purge legacy tiles $key: $e');
      }
    }
    try {
      await marker.writeAsString('1');
    } catch (e) {
      debugPrint('purge marker: $e');
    }
  }

  Directory get root {
    final r = _root;
    if (r == null) {
      throw StateError('TileCacheService.init() not called');
    }
    return r;
  }

  Future<void> _loadRegionsMeta() async {
    final file = File(p.join(root.path, 'regions.json'));
    if (!await file.exists()) {
      regions.clear();
      return;
    }
    try {
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      regions
        ..clear()
        ..addAll(
          list.map((e) => OfflineRegion.fromJson(e as Map<String, dynamic>)),
        );
    } catch (e) {
      debugPrint('Failed to load regions meta: $e');
      regions.clear();
    }
  }

  Future<void> _saveRegionsMeta() async {
    final file = File(p.join(root.path, 'regions.json'));
    await _writeAtomically(
      file,
      utf8.encode(jsonEncode(regions.map((r) => r.toJson()).toList())),
    );
  }

  /// Write via a unique temp file + rename so a crash or kill mid-write
  /// (common during a long offline download) never leaves a truncated file
  /// in place. A truncated tile used to be served from the cache forever and
  /// fail to decode; truncated regions.json dropped every saved region.
  static Future<void> _writeAtomically(File file, List<int> bytes) async {
    final tmp = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } catch (_) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      rethrow;
    }
  }

  File tileFile(String styleKey, int z, int x, int y) {
    return File(p.join(root.path, styleKey, '$z', '$x', '$y.png'));
  }

  Future<File?> findTile(String styleKey, int z, int x, int y) async {
    if (_root == null) return null;
    final f = tileFile(styleKey, z, x, y);
    if (await f.exists()) {
      // Self-heal: never serve a cached CARTO "API KEY REQUIRED" tile.
      try {
        final len = await f.length();
        if (isCartoPlaceholderSize(len) &&
            isCartoPlaceholderTile(await f.readAsBytes())) {
          await f.delete();
          return null;
        }
      } catch (_) {}
      _touch(f);
      return f;
    }
    return null;
  }

  /// Mark a cached tile as recently used (at most once per day per tile) so
  /// cap eviction removes tiles nobody looks at any more.
  void _touch(File f) {
    unawaited(() async {
      try {
        final m = await f.lastModified();
        final now = DateTime.now();
        if (now.difference(m) > const Duration(days: 1)) {
          await f.setLastModified(now);
        }
      } catch (_) {}
    }());
  }

  Future<void> writeTile(
    String styleKey,
    int z,
    int x,
    int y,
    List<int> bytes,
  ) async {
    if (isCartoPlaceholderTile(bytes)) return;
    final file = tileFile(styleKey, z, x, y);
    await file.parent.create(recursive: true);
    await _writeAtomically(file, bytes);
    if (++_writesSinceTrim >= _trimEveryWrites && !_downloading) {
      _writesSinceTrim = 0;
      unawaited(trimToCap());
    }
  }

  int estimateTiles({
    required LatLng center,
    required double radiusMeters,
    int minZoom = AppConstants.offlineMinZoom,
    int maxZoom = AppConstants.offlineMaxZoom,
  }) {
    return GeoMath.estimateTileCount(
      center: center,
      radiusMeters: radiusMeters,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }

  Future<OfflineRegion> downloadRegion({
    required String name,
    required LatLng center,
    required double radiusMeters,
    required String styleKey,
    required String urlTemplate,
    int minZoom = AppConstants.offlineMinZoom,
    int maxZoom = AppConstants.offlineMaxZoom,
  }) async {
    if (_downloading) {
      throw StateError('A download is already in progress');
    }
    if (!tileSourceAllowsBulkDownload(urlTemplate)) {
      throw StateError(
        'This map style does not allow offline downloads. '
        'Add a CARTO API key and use the Light or Dark style.',
      );
    }
    _downloading = true;
    _cancelRequested = false;

    final id =
        'r_${DateTime.now().millisecondsSinceEpoch}_${center.latitude.toStringAsFixed(3)}';
    final region = OfflineRegion(
      id: id,
      name: name,
      centerLat: center.latitude,
      centerLon: center.longitude,
      radiusMeters: radiusMeters,
      minZoom: minZoom,
      maxZoom: maxZoom,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      status: DownloadStatus.downloading,
    );
    regions.insert(0, region);
    await _saveRegionsMeta();

    final tiles = <({int x, int y, int z})>[];
    for (var z = minZoom; z <= maxZoom; z++) {
      tiles.addAll(
        GeoMath.tilesForCircle(
          center: center,
          radiusMeters: radiusMeters,
          z: z,
        ),
      );
    }
    region.tileCount = tiles.length;

    var done = 0;
    var bytes = 0;
    Object? failure;
    // Shared cursor instead of queue.removeAt(0): removing from the front of
    // a List is O(n), which made a 50 km region (tens of thousands of tiles)
    // quadratic on the UI isolate.
    var next = 0;

    Future<void> worker() async {
      while (true) {
        if (_cancelRequested) return;
        if (next >= tiles.length) return;
        final tile = tiles[next++];
        try {
          final file = tileFile(styleKey, tile.z, tile.x, tile.y);
          if (!await file.exists()) {
            final url = urlTemplate
                .replaceAll('{z}', '${tile.z}')
                .replaceAll('{x}', '${tile.x}')
                .replaceAll('{y}', '${tile.y}');
            final resp = await _client
                .get(
                  Uri.parse(url),
                  headers: {'User-Agent': AppConstants.userAgent},
                )
                .timeout(tileRequestTimeout);
            if (isTilePlaceholderResponse(resp)) {
              throw StateError(
                'CARTO returned "API KEY REQUIRED" — check the API key',
              );
            }
            if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
              await writeTile(
                styleKey,
                tile.z,
                tile.x,
                tile.y,
                resp.bodyBytes,
              );
              bytes += resp.bodyBytes.length;
            }
          } else {
            bytes += await file.length();
          }
        } catch (e) {
          debugPrint('tile download error $tile: ${redactTileKey('$e')}');
          if (e is StateError) {
            // Bad / missing key: stop instead of hammering the server.
            _cancelRequested = true;
            failure ??= e;
          }
        }
        done++;
        if (!_progressController.isClosed) {
          _progressController.add(
            DownloadProgress(
              regionId: id,
              done: done,
              total: tiles.length,
              bytes: bytes,
            ),
          );
        }
        await Future<void>.delayed(
          const Duration(milliseconds: AppConstants.tileDownloadDelayMs),
        );
      }
    }

    try {
      await Future.wait(
        List.generate(AppConstants.tileDownloadConcurrency, (_) => worker()),
      );
      if (failure != null) {
        region.status = DownloadStatus.failed;
      } else if (_cancelRequested) {
        region.status = DownloadStatus.cancelled;
      } else {
        region.status = DownloadStatus.complete;
      }
      region.bytes = bytes;
      region.tileCount = done;
      await _saveRegionsMeta();
      if (failure != null) throw failure!;
      return region;
    } catch (e) {
      region.status = DownloadStatus.failed;
      await _saveRegionsMeta();
      rethrow;
    } finally {
      _downloading = false;
    }
  }

  void cancelDownload() {
    _cancelRequested = true;
  }

  Future<void> deleteRegion(String id) async {
    OfflineRegion? region;
    for (final r in regions) {
      if (r.id == id) region = r;
    }
    regions.removeWhere((r) => r.id == id);
    await _saveRegionsMeta();
    if (region == null) return;
    // Best-effort: drop tiles whose file mtime is around this region.
    // Named regions share the style tree; only delete files unique to a
    // cancelled/failed region by pruning empty dirs after unused lookup.
    // Full wipe of a style would drop other regions, so we only prune
    // tiles that fall inside this region's circle.
    try {
      for (final style in allTileStyleKeys) {
        final tiles = <({int x, int y, int z})>[];
        for (var z = region.minZoom; z <= region.maxZoom; z++) {
          tiles.addAll(
            GeoMath.tilesForCircle(
              center: region.center,
              radiusMeters: region.radiusMeters,
              z: z,
            ),
          );
        }
        for (final t in tiles) {
          final f = tileFile(style, t.z, t.x, t.y);
          if (await f.exists()) {
            await f.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('deleteRegion files: $e');
    }
  }

  TileProvider createProvider({
    required String styleKey,
    required String urlTemplate,
  }) {
    return _CachingTileProvider(
      service: this,
      styleKey: styleKey,
      urlTemplate: urlTemplate,
      client: _client,
    );
  }

  Future<void> dispose() async {
    tilesFailing.dispose();
    await _progressController.close();
    _client.close();
  }
}

/// Sizes (bytes) of CARTO's keyless "API KEY REQUIRED" tiles (Voyager-style
/// light and Dark Matter), as served since 25 Sep 2026.
const _cartoPlaceholderSizes = {2049, 2513};

/// FNV-1a 32-bit hashes of those placeholder PNGs.
const _cartoPlaceholderHashes = {0xbf743404, 0x09d0920b};

int _fnv1a32(List<int> bytes) {
  var h = 0x811c9dc5;
  for (final b in bytes) {
    h = ((h ^ (b & 0xff)) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Cheap pre-check before reading a cached file.
bool isCartoPlaceholderSize(int length) =>
    _cartoPlaceholderSizes.contains(length);

/// Whether [bytes] is CARTO's "API KEY REQUIRED" placeholder tile.
bool isCartoPlaceholderTile(List<int> bytes) =>
    isCartoPlaceholderSize(bytes.length) &&
    _cartoPlaceholderHashes.contains(_fnv1a32(bytes));

/// CARTO serves the placeholder with HTTP 200, so check the body.
bool isTilePlaceholderResponse(http.Response resp) =>
    isCartoPlaceholderTile(resp.bodyBytes);

/// The z/x/y the tile server (and the offline cache) actually use for
/// [coordinates] in [options].
///
/// With `retinaMode` on a high-DPI screen flutter_map *simulates* retina by
/// adding 1 to [TileLayer.zoomOffset]; the coordinates it hands to a
/// provider are then tagged one zoom level below the URL zoom. Building URLs
/// from `coordinates.z` directly asked for x/y that do not exist at that
/// zoom (OSM answers 400 "invalid tile") and the map stayed blank.
@visibleForTesting
TileCoordinates resolveTileCoordinates(
  TileCoordinates coordinates,
  TileLayer options,
) {
  final z = (options.zoomOffset +
          (options.zoomReverse
              ? options.maxZoom - coordinates.z.toDouble()
              : coordinates.z.toDouble()))
      .round();
  final y = options.tms ? ((1 << z) - 1) - coordinates.y : coordinates.y;
  return TileCoordinates(coordinates.x, y, z);
}

class _CachingTileProvider extends TileProvider {
  _CachingTileProvider({
    required this.service,
    required this.styleKey,
    required this.urlTemplate,
    required this.client,
  });

  final TileCacheService service;
  final String styleKey;
  final String urlTemplate;
  final http.Client client;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _OfflineAwareImage(
      service: service,
      styleKey: styleKey,
      urlTemplate: urlTemplate,
      coordinates: resolveTileCoordinates(coordinates, options),
      client: client,
    );
  }
}

class _OfflineAwareImage extends ImageProvider<_OfflineAwareImage> {
  const _OfflineAwareImage({
    required this.service,
    required this.styleKey,
    required this.urlTemplate,
    required this.coordinates,
    required this.client,
  });

  final TileCacheService service;
  final String styleKey;
  final String urlTemplate;
  final TileCoordinates coordinates;
  final http.Client client;

  @override
  Future<_OfflineAwareImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _OfflineAwareImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1.0,
      debugLabel: 'tile/${coordinates.z}/${coordinates.x}/${coordinates.y}',
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final z = coordinates.z;
    final x = coordinates.x;
    final y = coordinates.y;

    final offline = await service.findTile(styleKey, z, x, y);
    if (offline != null) {
      try {
        final bytes = await offline.readAsBytes();
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return await decode(buffer);
      } catch (e) {
        // Corrupt cache entry (e.g. truncated by an older build): drop it and
        // fall through to the network instead of failing this tile forever.
        debugPrint('cached tile unreadable, refetching: $e');
        try {
          await offline.delete();
        } catch (_) {}
      }
    }

    final url = urlTemplate
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
    try {
      final resp = await client
          .get(
            Uri.parse(url),
            headers: {'User-Agent': AppConstants.userAgent},
          )
          .timeout(TileCacheService.tileRequestTimeout);
      if (resp.statusCode == 200 &&
          resp.bodyBytes.isNotEmpty &&
          !isTilePlaceholderResponse(resp)) {
        service.reportTileFetch(ok: true);
        try {
          await service.writeTile(styleKey, z, x, y, resp.bodyBytes);
        } catch (_) {}
        final buffer = await ui.ImmutableBuffer.fromUint8List(resp.bodyBytes);
        return await decode(buffer);
      }
      // 404 above the source's max zoom is normal; anything else is not.
      service.reportTileFetch(ok: resp.statusCode == 404);
    } catch (e) {
      service.reportTileFetch(ok: false);
      debugPrint('tile fetch failed: ${redactTileKey('$e')}');
    }

    // 1×1 transparent PNG fallback
    const transparentPng = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      Uint8List.fromList(transparentPng),
    );
    return await decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    return other is _OfflineAwareImage &&
        other.coordinates == coordinates &&
        other.styleKey == styleKey &&
        other.urlTemplate == urlTemplate;
  }

  @override
  int get hashCode => Object.hash(styleKey, urlTemplate, coordinates);
}

class CacheTrimResult {
  const CacheTrimResult(this.removedTiles, this.freedBytes);
  final int removedTiles;
  final int freedBytes;
}
