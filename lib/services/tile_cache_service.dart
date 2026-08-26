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

  Stream<DownloadProgress> get progress => _progressController.stream;
  bool get isDownloading => _downloading;

  Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    _root = Directory(p.join(support.path, 'offline_tiles'));
    await _root!.create(recursive: true);
    await _loadRegionsMeta();
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
    await file.writeAsString(
      jsonEncode(regions.map((r) => r.toJson()).toList()),
    );
  }

  File tileFile(String styleKey, int z, int x, int y) {
    return File(p.join(root.path, styleKey, '$z', '$x', '$y.png'));
  }

  Future<File?> findTile(String styleKey, int z, int x, int y) async {
    if (_root == null) return null;
    final f = tileFile(styleKey, z, x, y);
    if (await f.exists()) return f;
    return null;
  }

  Future<void> writeTile(
    String styleKey,
    int z,
    int x,
    int y,
    List<int> bytes,
  ) async {
    final file = tileFile(styleKey, z, x, y);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
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
    final queue = List<({int x, int y, int z})>.from(tiles);

    Future<void> worker() async {
      while (true) {
        if (_cancelRequested) return;
        if (queue.isEmpty) return;
        final tile = queue.removeAt(0);
        try {
          final file = tileFile(styleKey, tile.z, tile.x, tile.y);
          if (!await file.exists()) {
            final url = urlTemplate
                .replaceAll('{z}', '${tile.z}')
                .replaceAll('{x}', '${tile.x}')
                .replaceAll('{y}', '${tile.y}');
            final resp = await _client.get(
              Uri.parse(url),
              headers: {'User-Agent': AppConstants.userAgent},
            );
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
          debugPrint('tile download error $tile: $e');
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
      if (_cancelRequested) {
        region.status = DownloadStatus.cancelled;
      } else {
        region.status = DownloadStatus.complete;
      }
      region.bytes = bytes;
      region.tileCount = done;
      await _saveRegionsMeta();
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
      for (final style in ['light', 'dark', 'topo', 'cycle']) {
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
    await _progressController.close();
    _client.close();
  }
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
      coordinates: coordinates,
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
      final bytes = await offline.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    }

    final url = urlTemplate
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
    try {
      final resp = await client.get(
        Uri.parse(url),
        headers: {'User-Agent': AppConstants.userAgent},
      );
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        try {
          await service.writeTile(styleKey, z, x, y, resp.bodyBytes);
        } catch (_) {}
        final buffer = await ui.ImmutableBuffer.fromUint8List(resp.bodyBytes);
        return decode(buffer);
      }
    } catch (e) {
      debugPrint('tile fetch failed: $e');
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
    return decode(buffer);
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
