import 'geometry.dart';

/// Orientation rules shared by the map screen, the compass and the puck.
///
/// Conventions (verified against flutter_map 8 in test/map_orientation_test):
/// * Bearings/headings are true bearings: 0 = north, clockwise.
/// * `MapCamera.rotation` turns the map clockwise on screen; north is drawn at
///   that angle clockwise from "up". Course-up therefore uses
///   `rotation = -heading`, so the direction of travel points up.
/// * Map markers without `rotate: true` live in the map's rotated frame, so
///   anything drawn at a true bearing inside them points the right way on
///   screen in every orientation.

/// Map rotation that puts [headingDegrees] at the top of the screen.
double courseUpRotation(double headingDegrees) =>
    GeoMath.normalizeSignedDegrees(-headingDegrees);

/// Whether the map is (close enough to) north up.
bool isNorthUp(double mapRotationDegrees, {double toleranceDegrees = 1}) =>
    GeoMath.normalizeSignedDegrees(mapRotationDegrees).abs() <=
    toleranceDegrees;

/// Show the compass when the map is turned away from north, and always in
/// course-up so the driver can see where north is.
bool showCompass({
  required double mapRotationDegrees,
  required bool courseUpFollowing,
}) =>
    courseUpFollowing || !isNorthUp(mapRotationDegrees);

/// The true bearing the location puck should point at, or null for a plain
/// dot. While navigating, the route direction is a good stand-in when the
/// GPS has no heading (standing at a light); while browsing, an unknown
/// heading is shown as unknown rather than as "north".
double? puckHeadingDegrees({
  required double? fixHeading,
  required double? routeHeading,
  required bool navigating,
}) {
  if (fixHeading != null && fixHeading.isFinite) {
    return fixHeading % 360;
  }
  if (navigating && routeHeading != null && routeHeading.isFinite) {
    return routeHeading % 360;
  }
  return null;
}
