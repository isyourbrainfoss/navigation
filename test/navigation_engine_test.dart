import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navigation/core/geometry.dart';
import 'package:navigation/core/maneuver.dart';
import 'package:navigation/core/sun.dart';
import 'package:navigation/models/place.dart';
import 'package:navigation/models/route_plan.dart';
import 'package:navigation/services/location_service.dart';
import 'package:navigation/services/navigation_engine.dart';
import 'package:navigation/services/search_service.dart';

void main() {
  final origin = Place.fromLatLng(const LatLng(0, 0), name: 'A');
  final dest = Place.fromLatLng(const LatLng(0, 0.02), name: 'B');
  final path = [
    const LatLng(0, 0),
    const LatLng(0, 0.01),
    const LatLng(0, 0.02),
  ];

  RoutePlan plan({List<NavInstruction>? steps}) {
    final geom = path;
    final raw = steps ??
        [
          NavInstruction(
            text: 'Head out',
            distanceMeters: 500,
            durationSeconds: 60,
            location: path.first,
            type: 'depart',
          ),
          NavInstruction(
            text: 'You have arrived',
            distanceMeters: 0,
            durationSeconds: 0,
            location: path.last,
            type: 'arrive',
          ),
        ];
    return RoutePlan(
      origin: origin,
      destination: dest,
      mode: TravelMode.walk,
      geometry: geom,
      distanceMeters: GeoMath.pathLengthMeters(geom),
      durationSeconds: 120,
      instructions: withAlongMeters(raw, geom),
    );
  }

  LocationFix fix(LatLng p, {double acc = 5}) => LocationFix(
        position: p,
        accuracyMeters: acc,
        timestamp: DateTime.now(),
      );

  test('snaps onto the polyline and reports remaining', () {
    final engine = const NavigationEngine();
    final r = plan();
    final p = engine.update(
      fix: fix(const LatLng(0.0004, 0.01)),
      route: r,
      instructionIndex: 0,
    );
    expect(p.offRoute, isFalse);
    expect(p.remainingMeters, lessThan(r.distanceMeters));
    expect(p.traveledMeters, greaterThan(100));
    expect(p.snapped.longitude, closeTo(0.01, 0.002));
  });

  test('off-route when far from path', () {
    final engine = const NavigationEngine();
    final p = engine.update(
      fix: fix(const LatLng(1, 0.01)),
      route: plan(),
      instructionIndex: 0,
    );
    expect(p.offRoute, isTrue);
    expect(p.offRouteMeters, greaterThan(1000));
  });

  test('hysteresis: stays off-route until closer than exit', () {
    final engine = const NavigationEngine();
    final r = plan();
    // ~45 m off a 0-latitude line is about 0.0004 deg lat
    final midOff = engine.update(
      fix: fix(const LatLng(0.0005, 0.01)),
      route: r,
      instructionIndex: 0,
      wasOffRoute: true,
    );
    expect(midOff.offRouteMeters, greaterThan(20));
  });

  test('arrives near destination', () {
    final engine = const NavigationEngine();
    final p = engine.update(
      fix: fix(path.last),
      route: plan(),
      instructionIndex: 1,
    );
    expect(p.arrived, isTrue);
  });

  test('advances instruction after passing maneuver', () {
    final engine = const NavigationEngine();
    final r = plan();
    final p = engine.update(
      fix: fix(const LatLng(0, 0.015)),
      route: r,
      instructionIndex: 0,
    );
    expect(p.instructionIndex, greaterThanOrEqualTo(0));
    expect(p.current, isNotNull);
  });

  test('splitAt produces two polylines sharing snap', () {
    final nearest = GeoMath.nearestOnPolyline(const LatLng(0, 0.01), path);
    final split = GeoMath.splitAt(
      path: path,
      snapped: nearest.point,
      segmentIndex: nearest.segmentIndex,
    );
    expect(split.traveled.length, greaterThanOrEqualTo(2));
    expect(split.remaining.length, greaterThanOrEqualTo(2));
    expect(split.traveled.last.latitude, closeTo(split.remaining.first.latitude, 1e-9));
  });

  test('Sun.elevation is positive at noon equator', () {
    final noon = DateTime.utc(2026, 3, 21, 12);
    expect(Sun.elevationDegrees(noon, 0, 0), greaterThan(40));
    expect(Sun.isNight(DateTime.utc(2026, 3, 21, 0), 0, 0), isTrue);
  });

  test('single-point geometry does not throw', () {
    final engine = const NavigationEngine();
    final r = RoutePlan(
      origin: origin,
      destination: dest,
      mode: TravelMode.walk,
      geometry: const [LatLng(0, 0)],
      distanceMeters: 0,
      durationSeconds: 0,
      instructions: const [],
    );
    final p = engine.update(fix: fix(const LatLng(0, 0.01)), route: r, instructionIndex: 0);
    expect(p.offRoute, isTrue);
    expect(p.routeHeading, isA<double>());
  });

  test('isTurn skips name-changes', () {
    expect(Maneuver.isTurn(type: 'turn'), isTrue);
    expect(Maneuver.isTurn(type: 'continue'), isFalse);
    expect(Maneuver.isTurn(type: 'new name'), isFalse);
    expect(Maneuver.isTurn(type: 'roundabout'), isTrue);
  });

  test('windowed snap does not jump to a parallel road', () {
    final intended = [
      const LatLng(0, 0),
      const LatLng(0, 0.01),
      const LatLng(0, 0.02),
    ];
    final parallel = [
      const LatLng(0.0009, 0),
      const LatLng(0.0009, 0.01),
      const LatLng(0.0009, 0.02),
    ];
    final combined = [...intended, ...parallel];
    // ~60 m north of intended, ~40 m south of parallel — full scan prefers parallel.
    const here = LatLng(0.00054, 0.01);
    final onParallel = GeoMath.nearestOnPolyline(here, parallel);
    final onIntended = GeoMath.nearestOnPolyline(here, intended);
    expect(onParallel.meters, lessThan(onIntended.meters));
    final unconstrained = GeoMath.nearestOnPolyline(here, combined);
    expect(unconstrained.segmentIndex, greaterThanOrEqualTo(2));
    final windowed = GeoMath.nearestOnPolyline(
      here,
      combined,
      hintSegment: 0,
      windowSegments: 1,
    );
    expect(windowed.segmentIndex, lessThan(2));
    expect(windowed.meters, closeTo(onIntended.meters, 8));
  });

  test('off-route enter grows with GPS accuracy', () {
    final engine = const NavigationEngine();
    final r = plan();
    // ~45 m off the equator line.
    final tight = engine.update(
      fix: fix(const LatLng(0.0004, 0.01), acc: 5),
      route: r,
      instructionIndex: 0,
    );
    final loose = engine.update(
      fix: fix(const LatLng(0.0004, 0.01), acc: 40),
      route: r,
      instructionIndex: 0,
    );
    expect(tight.offRoute, isFalse);
    expect(loose.offRoute, isFalse);
    final farther = engine.update(
      fix: fix(const LatLng(0.0012, 0.01), acc: 40),
      route: r,
      instructionIndex: 0,
    );
    // 2.5*40 = 100 m enter; 0.0012 deg ≈ 133 m.
    expect(farther.offRouteMeters, greaterThan(100));
    expect(farther.offRoute, isTrue);
  });

  test('approaching last 80 m keeps follow side', () {
    final engine = const NavigationEngine();
    final r = plan(
      steps: [
        NavInstruction(
          text: 'Head out',
          distanceMeters: 2000,
          durationSeconds: 120,
          location: path.first,
          type: 'depart',
        ),
        NavInstruction(
          text: 'Arrive on the left',
          distanceMeters: 0,
          durationSeconds: 0,
          location: path.last,
          type: 'arrive',
          modifier: 'left',
        ),
      ],
    );
    // ~50 m before dest at lon 0.02 (1 deg ≈ 111 km).
    final p = engine.update(
      fix: fix(const LatLng(0, 0.01955)),
      route: r,
      instructionIndex: 0,
    );
    expect(p.arrived, isFalse);
    expect(p.approaching, isTrue);
    expect(p.remainingMeters, lessThan(80));
    expect(p.remainingMeters, greaterThan(25));
    expect(p.destinationSide, 'left');
  });

  test('ordinal 1/2/3/11', () {
    expect(Maneuver.ordinal(1), '1st');
    expect(Maneuver.ordinal(2), '2nd');
    expect(Maneuver.ordinal(3), '3rd');
    expect(Maneuver.ordinal(11), '11th');
    expect(Maneuver.ordinal(21), '21st');
  });

  test('coordinate parser', () {
    final s = SearchService();
    expect(s.parseCoordinates('52.52, 13.405')?.latitude, closeTo(52.52, 0.001));
    expect(s.parseCoordinates('geo:48.8,2.3')?.longitude, closeTo(2.3, 0.001));
    expect(s.parseCoordinates('hello'), isNull);
  });
}
