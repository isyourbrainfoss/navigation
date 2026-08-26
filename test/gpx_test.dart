import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navigation/models/place.dart';
import 'package:navigation/models/route_plan.dart';
import 'package:navigation/models/track.dart';
import 'package:navigation/services/gpx_service.dart';

void main() {
  test('round-trip a recorded track', () {
    final track = SavedTrack(
      id: 't1',
      name: 'Walk',
      createdAtMs: 1,
      distanceMeters: 100,
      points: const [
        TrackPoint(latitude: 52.5, longitude: 13.4, timestampMs: 1000),
        TrackPoint(latitude: 52.51, longitude: 13.41, timestampMs: 2000, elevation: 40),
      ],
    );
    final xml = GpxService().exportTrack(track);
    expect(xml, contains('<trkpt'));
    final doc = GpxService().parse(xml);
    expect(doc.tracks, isNotEmpty);
    expect(doc.tracks.first.points.length, 2);
    expect(doc.tracks.first.points.last.elevation, closeTo(40, 0.01));
  });

  test('parse waypoints and routes', () {
    const xml = '''
<?xml version="1.0"?>
<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
  <wpt lat="1.0" lon="2.0"><name>Camp</name></wpt>
  <rte>
    <rtept lat="1.0" lon="2.0"/>
    <rtept lat="1.1" lon="2.1"/>
  </rte>
</gpx>
''';
    final doc = GpxService().parse(xml);
    expect(doc.waypoints.single.name, 'Camp');
    expect(doc.routes.single.length, 2);
  });

  test('export route as rte', () {
    final plan = RoutePlan(
      origin: Place.fromLatLng(const LatLng(0, 0)),
      destination: Place.fromLatLng(const LatLng(1, 1), name: 'End'),
      mode: TravelMode.bike,
      geometry: const [LatLng(0, 0), LatLng(1, 1)],
      distanceMeters: 1000,
      durationSeconds: 100,
      instructions: const [],
    );
    final xml = GpxService().exportRoute(plan);
    expect(xml, contains('<rte>'));
    expect(xml.contains('End'), isTrue);
  });
}
