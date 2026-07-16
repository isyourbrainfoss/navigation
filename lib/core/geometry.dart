import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Pure geometry helpers for routing / offline tiles (unit-tested).
abstract final class GeoMath {
  static const _earthRadiusM = 6371000.0;

  static double haversineMeters(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Initial bearing from [a] to [b] in degrees [0, 360).
  static double bearingDegrees(LatLng a, LatLng b) {
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (_deg(math.atan2(y, x)) + 360) % 360;
  }

  /// Minimum distance from [point] to polyline [path] in meters.
  static double distanceToPolylineMeters(LatLng point, List<LatLng> path) {
    if (path.isEmpty) return double.infinity;
    if (path.length == 1) return haversineMeters(point, path.first);
    var min = double.infinity;
    for (var i = 0; i < path.length - 1; i++) {
      final d = _distanceToSegmentMeters(point, path[i], path[i + 1]);
      if (d < min) min = d;
    }
    return min;
  }

  /// Closest point on polyline + distance and segment index.
  static ({LatLng point, double meters, int segmentIndex}) nearestOnPolyline(
    LatLng point,
    List<LatLng> path,
  ) {
    if (path.isEmpty) {
      return (point: point, meters: double.infinity, segmentIndex: 0);
    }
    if (path.length == 1) {
      return (
        point: path.first,
        meters: haversineMeters(point, path.first),
        segmentIndex: 0,
      );
    }
    var bestDist = double.infinity;
    var bestPoint = path.first;
    var bestSeg = 0;
    for (var i = 0; i < path.length - 1; i++) {
      final proj = _projectOnSegment(point, path[i], path[i + 1]);
      final d = haversineMeters(point, proj);
      if (d < bestDist) {
        bestDist = d;
        bestPoint = proj;
        bestSeg = i;
      }
    }
    return (point: bestPoint, meters: bestDist, segmentIndex: bestSeg);
  }

  static double pathLengthMeters(List<LatLng> path) {
    var sum = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      sum += haversineMeters(path[i], path[i + 1]);
    }
    return sum;
  }

  // --- Web Mercator tile math ---

  static int lonToTileX(double lon, int z) {
    final n = 1 << z;
    final x = ((lon + 180.0) / 360.0 * n).floor();
    return x.clamp(0, n - 1);
  }

  static int latToTileY(double lat, int z) {
    final n = 1 << z;
    final latRad = _rad(lat.clamp(-85.05112878, 85.05112878));
    final y = ((1.0 -
                math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            n)
        .floor();
    return y.clamp(0, n - 1);
  }

  static double tileXToLon(int x, int z) {
    final n = 1 << z;
    return x / n * 360.0 - 180.0;
  }

  static double tileYToLat(int y, int z) {
    final n = 1 << z;
    final x = math.pi * (1 - 2 * y / n);
    final sinh = (math.exp(x) - math.exp(-x)) / 2;
    final latRad = math.atan(sinh);
    return _deg(latRad);
  }

  /// All tile coords covering a circle (center + radius meters) for zoom [z].
  static List<({int x, int y, int z})> tilesForCircle({
    required LatLng center,
    required double radiusMeters,
    required int z,
  }) {
    final latDelta = radiusMeters / 111320.0;
    final lonDelta =
        radiusMeters / (111320.0 * math.cos(_rad(center.latitude)).abs().clamp(0.01, 1.0));
    final minLat = center.latitude - latDelta;
    final maxLat = center.latitude + latDelta;
    final minLon = center.longitude - lonDelta;
    final maxLon = center.longitude + lonDelta;

    final xMin = lonToTileX(minLon, z);
    final xMax = lonToTileX(maxLon, z);
    final yMin = latToTileY(maxLat, z); // north → smaller y
    final yMax = latToTileY(minLat, z);

    final tiles = <({int x, int y, int z})>[];
    for (var x = xMin; x <= xMax; x++) {
      for (var y = yMin; y <= yMax; y++) {
        // Optional: keep tiles whose center is roughly within radius * 1.2
        final tLat = tileYToLat(y, z);
        final tLon = tileXToLon(x, z);
        final nextLat = tileYToLat(y + 1, z);
        final nextLon = tileXToLon(x + 1, z);
        final mid = LatLng((tLat + nextLat) / 2, (tLon + nextLon) / 2);
        if (haversineMeters(center, mid) <= radiusMeters * 1.35) {
          tiles.add((x: x, y: y, z: z));
        }
      }
    }
    return tiles;
  }

  static int estimateTileCount({
    required LatLng center,
    required double radiusMeters,
    required int minZoom,
    required int maxZoom,
  }) {
    var n = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      n += tilesForCircle(center: center, radiusMeters: radiusMeters, z: z)
          .length;
    }
    return n;
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double _deg(double rad) => rad * 180.0 / math.pi;

  static double _distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final proj = _projectOnSegment(p, a, b);
    return haversineMeters(p, proj);
  }

  static LatLng _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    // Local equirectangular projection around a.
    final cosLat = math.cos(_rad(a.latitude));
    final bx = (b.longitude - a.longitude) * cosLat;
    final by = b.latitude - a.latitude;
    final px = (p.longitude - a.longitude) * cosLat;
    final py = p.latitude - a.latitude;
    final ab2 = bx * bx + by * by;
    if (ab2 < 1e-18) return a;
    var t = (px * bx + py * by) / ab2;
    t = t.clamp(0.0, 1.0);
    return LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
  }
}

/// Decode Google-encoded polyline to [LatLng] list.
List<LatLng> decodePolyline(String encoded, {int precision = 5}) {
  final coords = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lon = 0;
  final factor = math.pow(10, precision).toInt();

  while (index < encoded.length) {
    lat += _decodePolylineValue(encoded, () => index, (i) => index = i);
    lon += _decodePolylineValue(encoded, () => index, (i) => index = i);
    coords.add(LatLng(lat / factor, lon / factor));
  }
  return coords;
}

int _decodePolylineValue(
  String encoded,
  int Function() getIndex,
  void Function(int) setIndex,
) {
  var result = 0;
  var shift = 0;
  int b;
  var index = getIndex();
  do {
    b = encoded.codeUnitAt(index++) - 63;
    result |= (b & 0x1f) << shift;
    shift += 5;
  } while (b >= 0x20 && index < encoded.length);
  setIndex(index);
  return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
}
