import 'package:latlong2/latlong.dart';

import '../core/format.dart';
import 'place.dart';

enum TravelMode { walk, bike, drive, truck }

extension TravelModeX on TravelMode {
  String get label => switch (this) {
        TravelMode.walk => 'Walk',
        TravelMode.bike => 'Bike',
        TravelMode.drive => 'Drive',
        TravelMode.truck => 'Truck',
      };

  String get iconName => switch (this) {
        TravelMode.walk => 'directions_walk',
        TravelMode.bike => 'directions_bike',
        TravelMode.drive => 'directions_car',
        TravelMode.truck => 'local_shipping',
      };
}

class LaneInfo {
  const LaneInfo({required this.indications, required this.valid});

  /// OSRM lane indications, e.g. `left`, `straight`, `right`.
  final List<String> indications;
  final bool valid;
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
    this.lanes = const [],
    this.alongMeters = 0,
    this.exit,
  });

  final String text;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng location;
  final String? modifier;
  final String? type;
  final String? name;
  final List<LaneInfo> lanes;
  final double alongMeters;
  final int? exit;
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
    this.vias = const [],
    this.label = '',
    this.maxSpeedKph = const [],
    this.summary = '',
  });

  final Place origin;
  final Place destination;
  final List<Place> vias;
  final TravelMode mode;
  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final List<NavInstruction> instructions;
  final String label;
  final List<double?> maxSpeedKph;
  final String summary;

  String formatDistance({bool metric = true}) =>
      formatDistanceMeters(distanceMeters, metric: metric);

  String formatDuration() => formatDurationSeconds(durationSeconds);
}
