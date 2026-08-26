String formatDistanceMeters(double meters, {required bool metric}) {
  final m = meters.abs();
  if (metric) {
    if (m < 30) return '${m.round()} m';
    if (m < 1000) {
      final rounded = (m / 10).round() * 10;
      return '$rounded m';
    }
    return '${(m / 1000).toStringAsFixed(m < 10000 ? 1 : 0)} km';
  }
  final miles = m / 1609.344;
  if (miles < 0.1) return '${(m * 3.28084).round()} ft';
  return '${miles.toStringAsFixed(miles < 10 ? 1 : 0)} mi';
}

String formatDurationSeconds(double seconds) {
  final total = seconds.round().clamp(0, 7 * 24 * 3600);
  if (total < 60) return '<1 min';
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  if (h == 0) return '$m min';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

String formatEtaClock(DateTime eta) {
  final h = eta.hour.toString().padLeft(2, '0');
  final m = eta.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String formatSpeed(double metersPerSecond, {required bool metric}) {
  if (metersPerSecond < 0) return metric ? '0 km/h' : '0 mph';
  if (metric) {
    return '${(metersPerSecond * 3.6).round()} km/h';
  }
  return '${(metersPerSecond * 2.236936).round()} mph';
}

String formatAltitude(double meters, {required bool metric}) {
  if (metric) return '${meters.round()} m';
  return '${(meters * 3.28084).round()} ft';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String formatRadiusKm(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
}

String formatAccuracy(double meters) {
  if (meters < 1) return '<1 m';
  return '±${meters.round()} m';
}
