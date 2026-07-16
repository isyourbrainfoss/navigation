import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navigation/core/geometry.dart';

void main() {
  group('GeoMath.haversineMeters', () {
    test('zero for same point', () {
      const p = LatLng(52.52, 13.405);
      expect(GeoMath.haversineMeters(p, p), 0);
    });

    test('roughly 1 degree latitude ≈ 111 km', () {
      const a = LatLng(0, 0);
      const b = LatLng(1, 0);
      final d = GeoMath.haversineMeters(a, b);
      expect(d, closeTo(111195, 500));
    });
  });

  group('decodePolyline', () {
    test('decodes classic OSRM sample segment', () {
      // Encoded polyline for a short segment (precision 5).
      // Known pair near 38.5, -120.2 → 40.7, -120.95
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final pts = decodePolyline(encoded);
      expect(pts.length, greaterThanOrEqualTo(2));
      expect(pts.first.latitude, closeTo(38.5, 0.1));
      expect(pts.first.longitude, closeTo(-120.2, 0.1));
    });

    test('empty string → empty list', () {
      expect(decodePolyline(''), isEmpty);
    });
  });

  group('distanceToPolyline', () {
    test('point on segment is ~0', () {
      final path = [
        const LatLng(0, 0),
        const LatLng(0, 1),
      ];
      final mid = const LatLng(0, 0.5);
      expect(GeoMath.distanceToPolylineMeters(mid, path), lessThan(50));
    });

    test('point far from path', () {
      final path = [
        const LatLng(0, 0),
        const LatLng(0, 1),
      ];
      final far = const LatLng(1, 0.5);
      expect(GeoMath.distanceToPolylineMeters(far, path), greaterThan(100000));
    });
  });

  group('tile math', () {
    test('lon 0 lat 0 at z0 is 0,0', () {
      expect(GeoMath.lonToTileX(0, 0), 0);
      expect(GeoMath.latToTileY(0, 0), 0);
    });

    test('estimate tiles grows with radius and zoom', () {
      const center = LatLng(52.52, 13.405);
      final small = GeoMath.estimateTileCount(
        center: center,
        radiusMeters: 5000,
        minZoom: 10,
        maxZoom: 12,
      );
      final large = GeoMath.estimateTileCount(
        center: center,
        radiusMeters: 20000,
        minZoom: 10,
        maxZoom: 12,
      );
      expect(small, greaterThan(0));
      expect(large, greaterThan(small));
    });
  });

  group('bearing', () {
    test('north is ~0', () {
      const a = LatLng(0, 0);
      const b = LatLng(1, 0);
      expect(GeoMath.bearingDegrees(a, b), closeTo(0, 1));
    });
  });
}
