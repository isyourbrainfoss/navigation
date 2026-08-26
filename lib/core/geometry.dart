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
  ///
  /// When [hintSegment] is set, searches `[hint-2, hint+windowSegments]` on the
  /// continuous piece containing the hint (stops at a reverse-jump connector)
  /// and only falls back to a full scan if that snap is farther than 70 m.
  static ({LatLng point, double meters, int segmentIndex}) nearestOnPolyline(
    LatLng point,
    List<LatLng> path, {
    int? hintSegment,
    int windowSegments = 48,
  }) {
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
    final last = path.length - 2;
    if (hintSegment != null) {
      var lo = hintSegment.clamp(0, last);
      var hi = lo;
      for (var step = 0; step < 2; step++) {
        final i = lo - 1;
        if (i < 0 || _isReverseJump(path, i)) break;
        lo = i;
      }
      for (var step = 0; step < windowSegments; step++) {
        final i = hi + 1;
        if (i > last || _isReverseJump(path, i)) break;
        hi = i;
      }
      final local = _nearestOnSegments(
        point,
        path,
        lo,
        hi,
        skipReverseJumps: false,
      );
      if (local.meters <= 70) return local;
    }
    return _nearestOnSegments(
      point,
      path,
      0,
      last,
      skipReverseJumps: true,
    );
  }

  static ({LatLng point, double meters, int segmentIndex}) _nearestOnSegments(
    LatLng point,
    List<LatLng> path,
    int fromSeg,
    int toSeg, {
    bool skipReverseJumps = false,
  }) {
    final lastSeg = path.length - 2;
    final start = fromSeg.clamp(0, lastSeg);
    final end = toSeg.clamp(0, lastSeg);
    var bestDist = double.infinity;
    var bestPoint = path[start];
    var bestSeg = start;
    for (var i = start; i <= end; i++) {
      if (skipReverseJumps && _isReverseJump(path, i)) continue;
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

  /// True when segment [i] reverses course across a long gap (concatenated
  /// parallel copies, not a real road connector).
  static bool _isReverseJump(List<LatLng> path, int i) {
    if (i < 1 || i >= path.length - 1) return false;
    final prev = bearingDegrees(path[i - 1], path[i]);
    final cur = bearingDegrees(path[i], path[i + 1]);
    var turn = (cur - prev).abs() % 360;
    if (turn > 180) turn = 360 - turn;
    final len = haversineMeters(path[i], path[i + 1]);
    return turn > 150 && len > 500;
  }

  static double pathLengthMeters(List<LatLng> path) {
    var sum = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      sum += haversineMeters(path[i], path[i + 1]);
    }
    return sum;
  }

  /// Cumulative distance at each vertex, meters from start.
  static List<double> cumulativeMeters(List<LatLng> path) {
    if (path.isEmpty) return const [];
    final c = List<double>.filled(path.length, 0);
    for (var i = 1; i < path.length; i++) {
      c[i] = c[i - 1] + haversineMeters(path[i - 1], path[i]);
    }
    return c;
  }

  /// Distance along [path] from start to [snapped] on [segmentIndex].
  static double traveledMeters({
    required LatLng snapped,
    required int segmentIndex,
    required List<LatLng> path,
    List<double>? cumulative,
  }) {
    if (path.isEmpty) return 0;
    final cum = cumulative ?? cumulativeMeters(path);
    if (segmentIndex < 0) return 0;
    if (segmentIndex >= path.length - 1) return cum.last;
    return cum[segmentIndex] + haversineMeters(path[segmentIndex], snapped);
  }

  /// Point at [meters] along [path] from the start.
  static LatLng pointAlongPath(List<LatLng> path, double meters) {
    if (path.isEmpty) return const LatLng(0, 0);
    if (path.length == 1 || meters <= 0) return path.first;
    var remaining = meters;
    for (var i = 0; i < path.length - 1; i++) {
      final seg = haversineMeters(path[i], path[i + 1]);
      if (remaining <= seg || i == path.length - 2) {
        final t = seg <= 1e-6 ? 0.0 : (remaining / seg).clamp(0.0, 1.0);
        return LatLng(
          path[i].latitude + t * (path[i + 1].latitude - path[i].latitude),
          path[i].longitude + t * (path[i + 1].longitude - path[i].longitude),
        );
      }
      remaining -= seg;
    }
    return path.last;
  }

  /// Split [path] at the snapped point. First list is traveled, second remaining.
  static ({List<LatLng> traveled, List<LatLng> remaining}) splitAt({
    required List<LatLng> path,
    required LatLng snapped,
    required int segmentIndex,
  }) {
    if (path.length < 2) {
      return (traveled: path, remaining: path);
    }
    final i = segmentIndex.clamp(0, path.length - 2);
    final traveled = <LatLng>[...path.sublist(0, i + 1), snapped];
    final remaining = <LatLng>[snapped, ...path.sublist(i + 1)];
    return (traveled: traveled, remaining: remaining);
  }

  static double lerpAngleDegrees(double a, double b, double t) {
    var d = ((b - a + 540) % 360) - 180;
    return (a + d * t + 360) % 360;
  }

  /// Destination point [meters] from [start] at [bearingDeg] (0 = north).
  static LatLng offset(LatLng start, double bearingDeg, double meters) {
    final br = _rad(bearingDeg);
    final lat1 = _rad(start.latitude);
    final lon1 = _rad(start.longitude);
    final ang = meters / _earthRadiusM;
    final lat2 = math.asin(
      math.sin(lat1) * math.cos(ang) +
          math.cos(lat1) * math.sin(ang) * math.cos(br),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(br) * math.sin(ang) * math.cos(lat1),
          math.cos(ang) - math.sin(lat1) * math.sin(lat2),
        );
    return LatLng(_deg(lat2), _deg(lon2));
  }

  static LatLng lerpLatLng(LatLng a, LatLng b, double t) {
    final u = t.clamp(0.0, 1.0);
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * u,
      a.longitude + (b.longitude - a.longitude) * u,
    );
  }

  /// Sample points along [path] roughly every [spacingMeters].
  static List<({LatLng point, double bearing})> samplesAlong(
    List<LatLng> path, {
    required double spacingMeters,
    int maxSamples = 24,
  }) {
    if (path.length < 2) return const [];
    final out = <({LatLng point, double bearing})>[];
    var acc = 0.0;
    var nextAt = spacingMeters;
    for (var i = 0; i < path.length - 1 && out.length < maxSamples; i++) {
      final a = path[i];
      final b = path[i + 1];
      final seg = haversineMeters(a, b);
      if (seg < 1) continue;
      final bearing = bearingDegrees(a, b);
      while (acc + seg >= nextAt && out.length < maxSamples) {
        final t = ((nextAt - acc) / seg).clamp(0.0, 1.0);
        out.add((
          point: LatLng(
            a.latitude + t * (b.latitude - a.latitude),
            a.longitude + t * (b.longitude - a.longitude),
          ),
          bearing: bearing,
        ));
        nextAt += spacingMeters;
      }
      acc += seg;
    }
    return out;
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
