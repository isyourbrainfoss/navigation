import 'package:flutter/material.dart';

import '../../models/route_plan.dart';

class LaneStrip extends StatelessWidget {
  const LaneStrip({super.key, required this.lanes});

  final List<LaneInfo> lanes;

  @override
  Widget build(BuildContext context) {
    if (lanes.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final lane in lanes)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              _icon(lane.indications),
              size: 22,
              color: lane.valid
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onPrimary.withValues(alpha: 0.28),
            ),
          ),
      ],
    );
  }

  IconData _icon(List<String> indications) {
    final joined = indications.join(' ').toLowerCase();
    if (joined.contains('sharp left') || joined.contains('sharp_left')) {
      return Icons.turn_sharp_left;
    }
    if (joined.contains('sharp right')) return Icons.turn_sharp_right;
    if (joined.contains('slight left')) return Icons.turn_slight_left;
    if (joined.contains('slight right')) return Icons.turn_slight_right;
    if (joined.contains('left')) return Icons.turn_left;
    if (joined.contains('right')) return Icons.turn_right;
    if (joined.contains('uturn')) return Icons.u_turn_left;
    return Icons.straight;
  }
}
