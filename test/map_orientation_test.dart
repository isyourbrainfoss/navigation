import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:navigation/core/geometry.dart';
import 'package:navigation/core/map_orientation.dart';
import 'package:navigation/features/map/widgets/map_controls.dart';
import 'package:navigation/features/map/widgets/user_puck.dart';

const _center = LatLng(59.93, 10.95); // Lørenskog

/// Screen-space direction (unit-ish vector) of a widget's local "up".
Offset _screenUp(WidgetTester tester, Finder transform) {
  // Measure the painted child: a RenderTransform's own coordinates are
  // outside its transform.
  final finder = find
      .descendant(of: transform, matching: find.byType(CustomPaint))
      .first;
  final box = tester.renderObject(finder) as RenderBox;
  final mid = box.size.center(Offset.zero);
  final a = box.localToGlobal(mid);
  final b = box.localToGlobal(mid.translate(0, -10));
  return (b - a) / 10;
}

void _expectDirection(Offset v, Offset expected) {
  expect(v.dx, closeTo(expected.dx, 0.02), reason: 'got $v want $expected');
  expect(v.dy, closeTo(expected.dy, 0.02), reason: 'got $v want $expected');
}

const _up = Offset(0, -1);
const _down = Offset(0, 1);
const _left = Offset(-1, 0);
const _right = Offset(1, 0);

Future<MapController> _pumpMap(
  WidgetTester tester, {
  required double rotation,
  List<Marker> markers = const [],
}) async {
  final controller = MapController();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 16,
            initialRotation: rotation,
          ),
          children: [MarkerLayer(markers: markers)],
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  group('angle maths', () {
    test('normalizeSignedDegrees wraps into (-180, 180]', () {
      expect(GeoMath.normalizeSignedDegrees(0), 0);
      expect(GeoMath.normalizeSignedDegrees(360), 0);
      expect(GeoMath.normalizeSignedDegrees(359), -1);
      expect(GeoMath.normalizeSignedDegrees(-90), -90);
      expect(GeoMath.normalizeSignedDegrees(270), -90);
      expect(GeoMath.normalizeSignedDegrees(180), 180);
      expect(GeoMath.normalizeSignedDegrees(-180), 180);
      expect(GeoMath.normalizeSignedDegrees(725), 5);
    });

    test('lerpAngleDegrees reaches north exactly (no 359.99 forever)', () {
      var a = 30.0;
      for (var i = 0; i < 200; i++) {
        a = GeoMath.lerpAngleDegrees(a, 0, 0.2);
      }
      expect(a, 0);
      expect(isNorthUp(a), isTrue);
      expect(showCompass(mapRotationDegrees: a, courseUpFollowing: false),
          isFalse);
    });

    test('lerpAngleDegrees takes the short way across the wrap', () {
      // From -170 to 170 is 20 degrees through 180, not 340 through 0.
      final step = GeoMath.lerpAngleDegrees(-170, 170, 0.5);
      expect(step, 180);
      final s2 = GeoMath.lerpAngleDegrees(-5, 355, 0.5);
      expect(s2, -5); // same angle: already there
    });

    test('course-up rotation is minus the heading, signed', () {
      expect(courseUpRotation(90), -90);
      expect(courseUpRotation(270), 90);
      expect(courseUpRotation(0), 0);
    });

    test('compass shows when rotated or in course-up', () {
      expect(showCompass(mapRotationDegrees: 0, courseUpFollowing: true),
          isTrue);
      expect(showCompass(mapRotationDegrees: 359.5, courseUpFollowing: false),
          isFalse);
      expect(showCompass(mapRotationDegrees: 20, courseUpFollowing: false),
          isTrue);
    });

    test('puck heading: unknown while browsing is a dot, not north', () {
      expect(
        puckHeadingDegrees(fixHeading: null, routeHeading: 80, navigating: false),
        isNull,
      );
      expect(
        puckHeadingDegrees(fixHeading: null, routeHeading: 80, navigating: true),
        80,
      );
      expect(
        puckHeadingDegrees(fixHeading: 370, routeHeading: 80, navigating: true),
        10,
      );
    });
  });

  group('on a real flutter_map', () {
    testWidgets('course-up while driving east puts north on the left',
        (tester) async {
      final c = await _pumpMap(tester, rotation: courseUpRotation(90));
      final mid = c.camera.latLngToScreenOffset(_center);
      final north = c.camera.latLngToScreenOffset(
        GeoMath.offset(_center, 0, 100),
      );
      final east = c.camera.latLngToScreenOffset(
        GeoMath.offset(_center, 90, 100),
      );
      // Direction of travel (east) is up; north is to the left.
      expect(east.dy, lessThan(mid.dy - 50));
      expect((east.dx - mid.dx).abs(), lessThan(2));
      expect(north.dx, lessThan(mid.dx - 50));
      expect((north.dy - mid.dy).abs(), lessThan(2));
    });

    for (final heading in [0.0, 45.0, 90.0, 200.0, 315.0]) {
      testWidgets('puck chevron points up in course-up (heading $heading)',
          (tester) async {
        await _pumpMap(
          tester,
          rotation: courseUpRotation(heading),
          markers: [
            Marker(
              point: _center,
              width: 72,
              height: 72,
              child: UserPuck(headingDegrees: heading, navigating: true),
            ),
          ],
        );
        _expectDirection(
          _screenUp(tester, find.byKey(const ValueKey('puck-chevron'))),
          _up,
        );
      });
    }

    testWidgets('puck chevron points at the heading in north-up',
        (tester) async {
      await _pumpMap(
        tester,
        rotation: 0,
        markers: [
          const Marker(
            point: _center,
            width: 72,
            height: 72,
            child: UserPuck(headingDegrees: 90),
          ),
        ],
      );
      _expectDirection(
        _screenUp(tester, find.byKey(const ValueKey('puck-chevron'))),
        _right,
      );
    });

    testWidgets('puck chevron is correct on a hand-rotated map',
        (tester) async {
      // User twisted the map 30° clockwise while heading south.
      await _pumpMap(
        tester,
        rotation: 30,
        markers: [
          const Marker(
            point: _center,
            width: 72,
            height: 72,
            child: UserPuck(headingDegrees: 180),
          ),
        ],
      );
      // South on screen is 180 + 30 = 210° clockwise from up.
      final v = _screenUp(tester, find.byKey(const ValueKey('puck-chevron')));
      _expectDirection(v, const Offset(-0.5, 0.866));
    });

    testWidgets('no heading while browsing draws a dot, not a chevron',
        (tester) async {
      await _pumpMap(
        tester,
        rotation: 0,
        markers: [
          const Marker(
            point: _center,
            width: 72,
            height: 72,
            child: UserPuck(),
          ),
        ],
      );
      expect(find.byKey(const ValueKey('puck-chevron')), findsNothing);
      expect(find.byKey(const ValueKey('puck-dot')), findsOneWidget);
    });
  });

  group('compass needle', () {
    Future<Offset> needleUp(WidgetTester tester, double rotation) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompassRose(
                mapRotationDegrees: rotation,
                onNorthUp: () {},
              ),
            ),
          ),
        ),
      );
      return _screenUp(tester, find.byKey(const ValueKey('compass-needle')));
    }

    testWidgets('matches where north is on the map', (tester) async {
      _expectDirection(await needleUp(tester, 0), _up);
      // Course-up driving east: north is left.
      _expectDirection(await needleUp(tester, courseUpRotation(90)), _left);
      // Driving west: north is right.
      _expectDirection(await needleUp(tester, courseUpRotation(270)), _right);
      // Driving south: north is down.
      _expectDirection(await needleUp(tester, courseUpRotation(180)), _down);
      // 359.9 and -0.1 are the same orientation.
      final a = await needleUp(tester, 359.9);
      final b = await needleUp(tester, -0.1);
      _expectDirection(a, b);
    });

    testWidgets('needle agrees with the map projection', (tester) async {
      for (final heading in [30.0, 135.0, 250.0]) {
        final rotation = courseUpRotation(heading);
        final c = await _pumpMap(tester, rotation: rotation);
        final mid = c.camera.latLngToScreenOffset(_center);
        final north = c.camera.latLngToScreenOffset(
          GeoMath.offset(_center, 0, 100),
        );
        final mapNorth = (north - mid) / (north - mid).distance;
        _expectDirection(await needleUp(tester, rotation), mapNorth);
      }
    });

    testWidgets('tap turns north up', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CompassRose(
                mapRotationDegrees: -90,
                onNorthUp: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CompassRose));
      expect(tapped, isTrue);
    });
  });
}
