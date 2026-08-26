import 'package:latlong2/latlong.dart';

import 'route_plan.dart';

class NavProgress {
  const NavProgress({
    required this.snapped,
    required this.segmentIndex,
    required this.offRouteMeters,
    required this.offRoute,
    required this.instructionIndex,
    required this.metersToNextManeuver,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.traveledMeters,
    required this.routeHeading,
    required this.arrived,
    this.current,
    this.thenNext,
    this.speedLimitKph,
    this.approaching = false,
    this.destinationSide,
  });

  final LatLng snapped;
  final int segmentIndex;
  final double offRouteMeters;
  final bool offRoute;
  final int instructionIndex;
  final double metersToNextManeuver;
  final double remainingMeters;
  final double remainingSeconds;
  final double traveledMeters;
  final double routeHeading;
  final bool arrived;
  final bool approaching;
  final String? destinationSide;
  final NavInstruction? current;
  final NavInstruction? thenNext;
  final double? speedLimitKph;
}
