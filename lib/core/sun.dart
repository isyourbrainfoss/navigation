import 'dart:math' as math;

/// Civil-twilight helper for night-driving auto mode. Approximate, no NOAA tables.
abstract final class Sun {
  /// Solar elevation in degrees at [utc] for [lat]/[lon]. Negative = below horizon.
  static double elevationDegrees(DateTime utc, double lat, double lon) {
    final t = utc.toUtc();
    final n = _dayOfYear(t) +
        (t.hour + t.minute / 60.0 + t.second / 3600.0) / 24.0;
    final decl = 23.44 *
        math.sin(_rad(360.0 / 365.0 * (n - 81)));
    final solarTime =
        (t.hour + t.minute / 60.0 + t.second / 3600.0 + lon / 15.0) % 24.0;
    final hourAngle = 15.0 * (solarTime - 12.0);
    final latR = _rad(lat);
    final declR = _rad(decl);
    final haR = _rad(hourAngle);
    final sinEl = math.sin(latR) * math.sin(declR) +
        math.cos(latR) * math.cos(declR) * math.cos(haR);
    return _deg(math.asin(sinEl.clamp(-1.0, 1.0)));
  }

  /// True during civil night (sun ≤ −6°).
  static bool isNight(DateTime now, double lat, double lon) {
    return elevationDegrees(now.toUtc(), lat, lon) <= -6;
  }

  static int _dayOfYear(DateTime t) {
    return DateTime.utc(t.year, t.month, t.day)
            .difference(DateTime.utc(t.year, 1, 1))
            .inDays +
        1;
  }

  static double _rad(double d) => d * math.pi / 180.0;
  static double _deg(double r) => r * 180.0 / math.pi;
}
