import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/maneuver.dart';
import '../../models/route_plan.dart';
import '../../providers/app_providers.dart';

Future<void> showInstructionSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const InstructionSheet(),
  );
}

class InstructionSheet extends ConsumerWidget {
  const InstructionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(mapSessionProvider);
    final metric = ref.watch(settingsProvider).metricUnits;
    final theme = Theme.of(context);
    final route = session.route;
    final instructions = route?.instructions ?? const <NavInstruction>[];
    final start = session.instructionIndex.clamp(0, instructions.length);
    final remaining = start < instructions.length
        ? instructions.sublist(start)
        : const <NavInstruction>[];
    final destName = session.destination?.name ?? route?.destination.name ?? '';
    final remainingM =
        session.progress?.remainingMeters ?? route?.distanceMeters;
    final metersTo = session.progress?.metersToNextManeuver;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.52,
      minChildSize: 0.32,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    destName.isEmpty ? 'Upcoming steps' : destName,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (remainingM != null)
                    Text(
                      formatDistanceMeters(remainingM, metric: metric),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: remaining.isEmpty
                  ? ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                      children: [
                        ListTile(
                          leading: const Icon(Icons.flag, size: 28),
                          title: const Text('You have arrived'),
                          subtitle: destName.isEmpty ? null : Text(destName),
                          minTileHeight: AppConstants.minTouchDp,
                        ),
                      ],
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                      itemCount: remaining.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final step = remaining[i];
                        final meters = i == 0
                            ? (metersTo ?? step.distanceMeters)
                            : step.distanceMeters;
                        return ListTile(
                          selected: i == 0,
                          leading: Icon(
                            Maneuver.icon(
                              type: step.type,
                              modifier: step.modifier,
                            ),
                            size: 28,
                          ),
                          title: Text(step.text),
                          subtitle: Text(
                            formatDistanceMeters(meters, metric: metric),
                          ),
                          minTileHeight: AppConstants.minTouchDp,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
