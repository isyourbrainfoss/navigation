class CameraView {
  const CameraView({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    this.rotation = 0,
  });

  final double latitude;
  final double longitude;
  final double zoom;
  final double rotation;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'zoom': zoom,
        'rotation': rotation,
      };

  factory CameraView.fromJson(Map<String, dynamic> json) => CameraView(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        zoom: (json['zoom'] as num).toDouble(),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      );
}
