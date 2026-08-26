import 'package:latlong2/latlong.dart';

class TrackPoint {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestampMs,
    this.elevation,
    this.speedMps,
  });

  final double latitude;
  final double longitude;
  final int timestampMs;
  final double? elevation;
  final double? speedMps;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lon': longitude,
        't': timestampMs,
        'ele': elevation,
        'spd': speedMps,
      };

  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lon'] as num).toDouble(),
        timestampMs: json['t'] as int? ?? 0,
        elevation: (json['ele'] as num?)?.toDouble(),
        speedMps: (json['spd'] as num?)?.toDouble(),
      );
}

class SavedTrack {
  const SavedTrack({
    required this.id,
    required this.name,
    required this.createdAtMs,
    required this.points,
    this.distanceMeters = 0,
  });

  final String id;
  final String name;
  final int createdAtMs;
  final List<TrackPoint> points;
  final double distanceMeters;

  List<LatLng> get latLngs => points.map((p) => p.latLng).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAtMs': createdAtMs,
        'distanceMeters': distanceMeters,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory SavedTrack.fromJson(Map<String, dynamic> json) => SavedTrack(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Track',
        createdAtMs: json['createdAtMs'] as int? ?? 0,
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
        points: ((json['points'] as List<dynamic>?) ?? [])
            .map((e) => TrackPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
