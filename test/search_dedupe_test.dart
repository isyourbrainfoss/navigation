import 'package:flutter_test/flutter_test.dart';
import 'package:navigation/models/place.dart';
import 'package:navigation/services/search_service.dart';

Place _p(String id, String name, double lat, double lon) =>
    Place(id: id, name: name, latitude: lat, longitude: lon);

void main() {
  test('same name within 300 m collapses to the first (best ranked)', () {
    final out = dedupeNearbySameName([
      _p('a', 'Oslo S', 59.9111, 10.7528),
      _p('b', 'Oslo S', 59.9109, 10.7535),
      _p('c', 'oslo s ', 59.9113, 10.7520),
      _p('d', 'Oslo S', 59.95, 10.80), // far away: a different place
      _p('e', 'Oslo Bussterminal', 59.9116, 10.7569),
    ]);
    expect(out.map((p) => p.id), ['a', 'd', 'e']);
  });

  test('place kind labels', () {
    expect(placeKindLabel('railway', 'station'), 'Train station');
    expect(placeKindLabel('amenity', 'bus_station'), 'Bus station');
    expect(placeKindLabel('amenity', 'ice_cream'), 'Ice cream');
    expect(placeKindLabel('place', 'house'), isNull);
    expect(placeKindLabel('building', 'yes'), isNull);
    expect(placeKindLabel('highway', 'residential'), isNull);
    expect(placeKindLabel('place', 'city'), 'City');
  });
}
