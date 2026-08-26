import 'package:latlong2/latlong.dart';

enum PlaceRole { none, home, work, parked }

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
    this.group = '',
    this.role = PlaceRole.none,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String subtitle;
  final String? osmKey;
  final String? osmValue;
  final String group;
  final PlaceRole role;

  LatLng get latLng => LatLng(latitude, longitude);

  String get displayLine {
    if (subtitle.isEmpty) return name;
    return '$name · $subtitle';
  }

  Place copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? subtitle,
    String? osmKey,
    String? osmValue,
    String? group,
    PlaceRole? role,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      subtitle: subtitle ?? this.subtitle,
      osmKey: osmKey ?? this.osmKey,
      osmValue: osmValue ?? this.osmValue,
      group: group ?? this.group,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'subtitle': subtitle,
        'osmKey': osmKey,
        'osmValue': osmValue,
        'group': group,
        'role': role.name,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Place',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        subtitle: json['subtitle'] as String? ?? '',
        osmKey: json['osmKey'] as String?,
        osmValue: json['osmValue'] as String?,
        group: json['group'] as String? ?? '',
        role: PlaceRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => PlaceRole.none,
        ),
      );

  factory Place.fromLatLng(LatLng ll, {String name = 'Pinned location'}) =>
      Place(
        id: 'pin_${ll.latitude.toStringAsFixed(5)}_${ll.longitude.toStringAsFixed(5)}',
        name: name,
        latitude: ll.latitude,
        longitude: ll.longitude,
      );
}
