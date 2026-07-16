import 'package:latlong2/latlong.dart';

enum DownloadStatus { idle, estimating, downloading, complete, failed, cancelled }

class OfflineRegion {
  OfflineRegion({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLon,
    required this.radiusMeters,
    required this.minZoom,
    required this.maxZoom,
    required this.createdAtMs,
    this.tileCount = 0,
    this.bytes = 0,
    this.status = DownloadStatus.complete,
  });

  final String id;
  final String name;
  final double centerLat;
  final double centerLon;
  final double radiusMeters;
  final int minZoom;
  final int maxZoom;
  final int createdAtMs;
  int tileCount;
  int bytes;
  DownloadStatus status;

  LatLng get center => LatLng(centerLat, centerLon);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'centerLat': centerLat,
        'centerLon': centerLon,
        'radiusMeters': radiusMeters,
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'createdAtMs': createdAtMs,
        'tileCount': tileCount,
        'bytes': bytes,
        'status': status.name,
      };

  factory OfflineRegion.fromJson(Map<String, dynamic> json) {
    DownloadStatus status = DownloadStatus.complete;
    for (final s in DownloadStatus.values) {
      if (s.name == json['status']) status = s;
    }
    return OfflineRegion(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Region',
      centerLat: (json['centerLat'] as num).toDouble(),
      centerLon: (json['centerLon'] as num).toDouble(),
      radiusMeters: (json['radiusMeters'] as num).toDouble(),
      minZoom: json['minZoom'] as int? ?? 8,
      maxZoom: json['maxZoom'] as int? ?? 16,
      createdAtMs: json['createdAtMs'] as int? ?? 0,
      tileCount: json['tileCount'] as int? ?? 0,
      bytes: json['bytes'] as int? ?? 0,
      status: status,
    );
  }
}

class DownloadProgress {
  const DownloadProgress({
    required this.regionId,
    required this.done,
    required this.total,
    required this.bytes,
    this.message = '',
  });

  final String regionId;
  final int done;
  final int total;
  final int bytes;
  final String message;

  double get fraction => total == 0 ? 0 : done / total;
}
