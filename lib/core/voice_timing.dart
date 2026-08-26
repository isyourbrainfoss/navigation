/// Spoken-prompt distances by travel mode (`walk`/`bike`/`drive`/`truck`) and speed.
/// Walk/bike are fixed. Drive/truck scale with speed, floored at 5 m/s.
abstract final class VoiceTiming {
  static double farMeters({required String modeName, required double speedMps}) {
    return switch (modeName) {
      'walk' => 80,
      'bike' => 200,
      _ => _driveMeters(speedMps, seconds: 20, min: 80, max: 800),
    };
  }

  static double nearMeters({required String modeName, required double speedMps}) {
    return switch (modeName) {
      'walk' => 40,
      'bike' => 80,
      _ => _driveMeters(speedMps, seconds: 8, min: 40, max: 300),
    };
  }

  static double nowMeters({required String modeName, required double speedMps}) {
    return switch (modeName) {
      'walk' => 15,
      'bike' => 30,
      _ => _driveMeters(speedMps, seconds: 2, min: 25, max: 80),
    };
  }

  static double _driveMeters(
    double speedMps, {
    required double seconds,
    required double min,
    required double max,
  }) {
    final v = speedMps < 5.0 ? 5.0 : speedMps;
    final m = v * seconds;
    if (m < min) return min;
    if (m > max) return max;
    return m;
  }
}
