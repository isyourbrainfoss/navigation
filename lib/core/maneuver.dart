import 'package:flutter/material.dart';

/// Maps OSRM/Valhalla maneuver type + modifier onto icons and spoken phrases.
abstract final class Maneuver {
  static IconData icon({String? type, String? modifier}) {
    final t = (type ?? '').toLowerCase().replaceAll('_', ' ');
    final m = (modifier ?? '').toLowerCase().replaceAll('_', ' ');

    if (t.contains('arrive') || t == 'destination') return Icons.flag;
    if (t.contains('depart') || t == 'start') return Icons.navigation;
    if (t.contains('uturn') || m.contains('uturn') || m.contains('u turn')) {
      return Icons.u_turn_left;
    }
    if (t.contains('roundabout') || t.contains('rotary') || t.contains('exit roundabout')) {
      return Icons.roundabout_right;
    }
    if (t.contains('merge')) return Icons.merge_type;
    if (t.contains('ramp') || t.contains('fork')) {
      if (m.contains('left')) return Icons.fork_left;
      if (m.contains('right')) return Icons.fork_right;
      return Icons.ramp_right;
    }
    if (t == 'continue' || t == 'new name' || t == 'straight') {
      return Icons.straight;
    }

    if (m.contains('sharp left')) return Icons.turn_sharp_left;
    if (m.contains('sharp right')) return Icons.turn_sharp_right;
    if (m.contains('slight left')) return Icons.turn_slight_left;
    if (m.contains('slight right')) return Icons.turn_slight_right;
    if (m == 'left' || m.endsWith(' left')) return Icons.turn_left;
    if (m == 'right' || m.endsWith(' right')) return Icons.turn_right;
    if (m.contains('straight')) return Icons.straight;

    if (t.contains('left')) return Icons.turn_left;
    if (t.contains('right')) return Icons.turn_right;
    return Icons.straight;
  }

  static String ordinal(int n) {
    if (n <= 0) return '$n';
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  static bool isTurn({String? type}) {
    final t = (type ?? '').toLowerCase().replaceAll('_', ' ');
    return t.isNotEmpty &&
        t != 'continue' &&
        t != 'new name' &&
        t != 'notification' &&
        t != 'depart';
  }

  static String spoken({
    required String text,
    required double metersToManeuver,
    required bool metric,
    required bool now,
  }) {
    if (now || metersToManeuver < 25) {
      return text.toLowerCase().startsWith('you ') ? text : 'Now, $text';
    }
    final dist = _spokenDistance(metersToManeuver, metric: metric);
    return 'In $dist, ${text[0].toLowerCase()}${text.substring(1)}';
  }

  static String _spokenDistance(double meters, {required bool metric}) {
    if (metric) {
      if (meters < 1000) {
        final rounded = meters < 80 ? meters.round() : (meters / 50).round() * 50;
        return '$rounded meters';
      }
      final km = meters / 1000;
      if (km < 10) {
        return '${km.toStringAsFixed(1)} kilometers';
      }
      return '${km.round()} kilometers';
    }
    final feet = meters * 3.28084;
    if (feet < 1000) return '${((feet / 50).round() * 50)} feet';
    final miles = meters / 1609.344;
    return '${miles.toStringAsFixed(miles < 10 ? 1 : 0)} miles';
  }
}
