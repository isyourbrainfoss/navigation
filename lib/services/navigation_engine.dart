import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../core/geometry.dart';
import '../models/nav_progress.dart';
import '../models/route_plan.dart';
import 'location_service.dart';

/// Pure snap / remaining / instruction-progress math. No I/O.
class NavigationEngine {
  const NavigationEngine();

  NavProgress update({
    required LocationFix fix,
    required RoutePlan route,
    required int instructionIndex,
    bool wasOffRoute = false,
    int? hintSegment,
  }) {
    final path = route.geometry;
    final destinationSide = _destinationSide(route);
    if (path.length < 2) {
      final snapped = path.isEmpty ? fix.position : path.first;
      return NavProgress(
        snapped: snapped,
        segmentIndex: 0,
        offRouteMeters: path.isEmpty
            ? double.infinity
            : GeoMath.haversineMeters(fix.position, snapped),
        offRoute: true,
        instructionIndex: 0,
        metersToNextManeuver: 0,
        remainingMeters: 0,
        remainingSeconds: 0,
        traveledMeters: 0,
        routeHeading: fix.heading ?? 0,
        arrived: false,
        approaching: true,
        destinationSide: destinationSide,
      );
    }

    final nearest = GeoMath.nearestOnPolyline(
      fix.position,
      path,
      hintSegment: hintSegment,
    );
    final off = nearest.meters;
    final enter = math.max(
      AppConstants.offRouteEnterMeters,
      2.5 * fix.accuracyMeters,
    );
    final exit = math.max(
      AppConstants.offRouteExitMeters,
      fix.accuracyMeters,
    );
    final offRoute = wasOffRoute ? off > exit : off > enter;

    final cum = GeoMath.cumulativeMeters(path);
    final total = cum.isEmpty ? route.distanceMeters : cum.last;
    final traveled = GeoMath.traveledMeters(
      snapped: nearest.point,
      segmentIndex: nearest.segmentIndex,
      path: path,
      cumulative: cum,
    );
    final remainingM = (total - traveled).clamp(0.0, total);
    final remainingS = total <= 0
        ? 0.0
        : route.durationSeconds * (remainingM / total);

    final arrived = GeoMath.haversineMeters(
              fix.position,
              route.destination.latLng,
            ) <=
            AppConstants.arrivalMeters ||
        remainingM <= AppConstants.arrivalMeters;
    final approaching =
        !arrived && remainingM <= AppConstants.approachingMeters;

    var idx = instructionIndex.clamp(
      0,
      route.instructions.isEmpty ? 0 : route.instructions.length - 1,
    );
    if (route.instructions.isNotEmpty) {
      for (var i = idx; i < route.instructions.length; i++) {
        final along = route.instructions[i].alongMeters;
        // Advance once we have passed this maneuver by a few meters.
        if (traveled + 8 >= along && i < route.instructions.length - 1) {
          idx = i + 1;
        } else {
          break;
        }
      }
    }

    final current =
        route.instructions.isEmpty ? null : route.instructions[idx];
    final thenNext = (current != null && idx + 1 < route.instructions.length)
        ? route.instructions[idx + 1]
        : null;

    var metersTo = 0.0;
    if (current != null) {
      final along = current.alongMeters;
      metersTo = (along - traveled).clamp(0.0, double.infinity);
      if (metersTo < 4 && thenNext != null) {
        metersTo = (thenNext.alongMeters - traveled).clamp(0.0, double.infinity);
      }
    }

    final headingSeg = nearest.segmentIndex.clamp(0, path.length - 2);
    final routeHeading = GeoMath.bearingDegrees(
      path[headingSeg],
      path[headingSeg + 1],
    );

    double? limit;
    if (route.maxSpeedKph.isNotEmpty) {
      final li = nearest.segmentIndex.clamp(0, route.maxSpeedKph.length - 1);
      limit = route.maxSpeedKph[li];
    }

    return NavProgress(
      snapped: nearest.point,
      segmentIndex: nearest.segmentIndex,
      offRouteMeters: off,
      offRoute: offRoute && !arrived,
      instructionIndex: idx,
      metersToNextManeuver: metersTo,
      remainingMeters: remainingM,
      remainingSeconds: remainingS,
      traveledMeters: traveled,
      routeHeading: routeHeading,
      arrived: arrived,
      current: current,
      thenNext: thenNext,
      speedLimitKph: limit,
      approaching: approaching,
      destinationSide: destinationSide,
    );
  }
}

String? _destinationSide(RoutePlan route) {
  if (route.instructions.isEmpty) return null;
  final modifier = route.instructions.last.modifier?.toLowerCase() ?? '';
  if (modifier.contains('left')) return 'left';
  if (modifier.contains('right')) return 'right';
  return null;
}

/// Annotate each instruction with distance-along-route so the engine can
/// advance by progress instead of nearest-maneuver.
List<NavInstruction> withAlongMeters(
  List<NavInstruction> steps,
  List<LatLng> path,
) {
  if (path.isEmpty) return steps;
  final cum = GeoMath.cumulativeMeters(path);
  return [
    for (final step in steps)
      () {
        final nearest = GeoMath.nearestOnPolyline(step.location, path);
        return NavInstruction(
          text: step.text,
          distanceMeters: step.distanceMeters,
          durationSeconds: step.durationSeconds,
          location: step.location,
          modifier: step.modifier,
          type: step.type,
          name: step.name,
          lanes: step.lanes,
          exit: step.exit,
          alongMeters: GeoMath.traveledMeters(
            snapped: nearest.point,
            segmentIndex: nearest.segmentIndex,
            path: path,
            cumulative: cum,
          ),
        );
      }(),
  ];
}
