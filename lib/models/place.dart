import 'package:latlong2/latlong.dart';

/// A searchable / navigable place.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.subtitle = '',
    this.osmKey,
    this.osmValue,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String subtitle;
  final String? osmKey;
  final String? osmValue;

  LatLng get latLng => LatLng(latitude, longitude);

  String get displayLine {
    if (subtitle.isEmpty) return name;
    return '$name · $subtitle';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'subtitle': subtitle,
        'osmKey': osmKey,
        'osmValue': osmValue,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Place',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        subtitle: json['subtitle'] as String? ?? '',
        osmKey: json['osmKey'] as String?,
        osmValue: json['osmValue'] as String?,
      );

  factory Place.fromLatLng(LatLng ll, {String name = 'Pinned location'}) =>
      Place(
        id: 'pin_${ll.latitude.toStringAsFixed(5)}_${ll.longitude.toStringAsFixed(5)}',
        name: name,
        latitude: ll.latitude,
        longitude: ll.longitude,
      );
}
