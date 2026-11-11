import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/core/constants.dart';
import 'package:navigation/services/tile_cache_service.dart';

void main() {
  // Oslo at z12 (x 2171, y 1190): what flutter_map hands the provider when
  // it simulates retina is the z12 grid tagged with the layer zoom 11.
  const fromLayer = TileCoordinates(2171, 1190, 11);

  test('simulated retina: URL/cache zoom includes the +1 offset', () {
    final layer = TileLayer(
      urlTemplate: AppConstants.tileUrlOsm,
      retinaMode: true,
    );
    expect(layer.resolvedRetinaMode, RetinaMode.simulation);
    final r = resolveTileCoordinates(fromLayer, layer);
    expect((r.z, r.x, r.y), (12, 2171, 1190));
    // Must be a real tile at that zoom.
    expect(r.x, lessThan(1 << r.z));
    expect(r.y, lessThan(1 << r.z));
  });

  test('no retina: coordinates are used as-is', () {
    final layer = TileLayer(urlTemplate: AppConstants.tileUrlOsm);
    final r = resolveTileCoordinates(
      const TileCoordinates(1085, 595, 11),
      layer,
    );
    expect((r.z, r.x, r.y), (11, 1085, 595));
  });
}
