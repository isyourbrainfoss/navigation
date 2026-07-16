import 'package:latlong2/latlong.dart';

import 'place.dart';

enum TravelMode { walk, drive }

extension TravelModeX on TravelMode {
  String get label => switch (this) {
        TravelMode.walk => 'Walk',
        TravelMode.drive => 'Drive',
      };

  String get iconName => switch (this) {
        TravelMode.walk => 'directions_walk',
        TravelMode.drive => 'directions_car',
      };
}

class NavInstruction {
  const NavInstruction({
    required this.text,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
    this.modifier,
    this.type,
    this.name,
  });

  final String text;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng location;
  final String? modifier;
  final String? type;
  final String? name;
}

class RoutePlan {
  const RoutePlan({
    required this.origin,
    required this.destination,
    required this.mode,
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.instructions,
  });

  final Place origin;
  final Place destination;
  final TravelMode mode;
  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final List<NavInstruction> instructions;

  String formatDistance({bool metric = true}) {
    if (metric) {
      if (distanceMeters < 1000) {
        return '${distanceMeters.round()} m';
      }
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    final miles = distanceMeters / 1609.344;
    if (miles < 0.1) {
      return '${(distanceMeters * 3.28084).round()} ft';
    }
    return '${miles.toStringAsFixed(1)} mi';
  }

  String formatDuration() {
    final total = durationSeconds.round();
    if (total < 60) return '<1 min';
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    if (h == 0) return '$m min';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}
