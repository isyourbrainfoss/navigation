import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../providers/app_providers.dart';

class GuidanceBanner extends ConsumerWidget {
  const GuidanceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(mapSessionProvider);
    final settings = ref.watch(settingsProvider);
    if (session.phase != NavPhase.navigating &&
        session.phase != NavPhase.arrived) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final route = session.route;
    if (route == null) return const SizedBox.shrink();

    final idx = session.instructionIndex.clamp(0, route.instructions.length - 1);
    final step = route.instructions.isEmpty
        ? null
        : route.instructions[idx];

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  session.phase == NavPhase.arrived
                      ? Icons.flag
                      : Icons.turn_right,
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.phase == NavPhase.arrived
                            ? 'You have arrived'
                            : (step?.text ?? 'Continue'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (session.phase == NavPhase.navigating && step != null)
                        Text(
                          formatDistanceMeters(
                            step.distanceMeters,
                            metric: settings.metricUnits,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Stop',
                  onPressed: () =>
                      ref.read(mapSessionProvider.notifier).stopNavigation(),
                  icon: Icon(
                    Icons.close,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            if (session.phase == NavPhase.navigating) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    route.formatDuration(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    route.formatDistance(metric: settings.metricUnits),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    route.destination.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
            if (session.phase == NavPhase.arrived) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.read(mapSessionProvider.notifier).clearArrived(),
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
