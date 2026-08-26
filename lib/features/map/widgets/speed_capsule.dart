import 'package:flutter/material.dart';

import '../../../core/format.dart';

/// Driving speed well: [formatSpeed] at 28sp tabular, glass-like Material.
class SpeedCapsule extends StatelessWidget {
  const SpeedCapsule({
    super.key,
    required this.speedMps,
    required this.metric,
  });

  final double speedMps;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: dark ? 0.88 : 0.94),
      elevation: 6,
      shadowColor: const Color(0x33000000),
      clipBehavior: Clip.antiAlias,
      shape: StadiumBorder(
        side: BorderSide(
          color: Colors.white.withValues(alpha: dark ? 0.08 : 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          formatSpeed(speedMps, metric: metric),
          maxLines: 1,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
