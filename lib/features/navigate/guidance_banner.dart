import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/maneuver.dart';
import '../../providers/app_providers.dart';
import '../map/widgets/glass.dart';
import 'instruction_sheet.dart';
import 'lane_strip.dart';

class GuidanceBanner extends ConsumerWidget {
  const GuidanceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(mapSessionProvider);
    final settings = ref.watch(settingsProvider);
    final fix = ref.watch(locationFixProvider).valueOrNull ??
        ref.watch(locationServiceProvider).lastFix;
    if (session.phase != NavPhase.navigating &&
        session.phase != NavPhase.arrived) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final route = session.route;
    if (route == null) return const SizedBox.shrink();
    final progress = session.progress;
    var step = progress?.current ??
        (route.instructions.isEmpty
            ? null
            : route.instructions[session.instructionIndex.clamp(
                0,
                route.instructions.length - 1,
              )]);
    var thenNext = progress?.thenNext;
    if (step != null &&
        !Maneuver.isTurn(type: step.type) &&
        thenNext != null) {
      step = thenNext;
      final idx = session.instructionIndex + 1;
      thenNext = idx + 1 < route.instructions.length
          ? route.instructions[idx + 1]
          : null;
    }
    final metersTo = progress?.metersToNextManeuver ?? step?.distanceMeters ?? 0;
    final remainingM = progress?.remainingMeters ?? route.distanceMeters;
    final remainingS = progress?.remainingSeconds ?? route.durationSeconds;
    final destName = session.destination?.name ?? route.destination.name;
    final approaching = progress?.approaching == true ||
        remainingM <= AppConstants.approachingMeters;
    final eta = DateTime.now().add(Duration(seconds: remainingS.round()));
    final speed = fix?.speedMps ?? 0;
    final arrived = session.phase == NavPhase.arrived;
    final onPrimary = arrived
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 10,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(24),
          color: arrived
              ? theme.colorScheme.secondary
              : theme.colorScheme.primary,
          child: InkWell(
            onTap: () => showInstructionSheet(context),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          arrived
                              ? Icons.check_rounded
                              : Maneuver.icon(
                                  type: step?.type,
                                  modifier: step?.modifier,
                                ),
                          size: 44,
                          color: onPrimary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!arrived)
                              Text(
                                formatDistanceMeters(
                                  metersTo,
                                  metric: settings.metricUnits,
                                ),
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: onPrimary,
                                  height: 0.95,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            Text(
                              arrived
                                  ? 'You have arrived'
                                  : (step?.text ?? 'Continue'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: onPrimary,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                            if (!arrived && approaching) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Destination ahead',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: onPrimary.withValues(alpha: 0.82),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (destName.isNotEmpty)
                                Text(
                                  destName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: onPrimary.withValues(alpha: 0.82),
                                  ),
                                ),
                            ] else if (!arrived && thenNext != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Then ${thenNext.text}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: onPrimary.withValues(alpha: 0.82),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!arrived && step != null && step.lanes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    LaneStrip(lanes: step.lanes),
                  ],
                  if (session.rerouting)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Glass(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              _stat(
                theme,
                Icons.schedule,
                '${formatDurationSeconds(remainingS)} · ${formatEtaClock(eta)}',
              ),
              _stat(
                theme,
                Icons.straighten,
                formatDistanceMeters(remainingM, metric: settings.metricUnits),
              ),
              if (settings.showSpeed)
                _stat(
                  theme,
                  Icons.speed,
                  formatSpeed(speed, metric: settings.metricUnits),
                ),
              const Spacer(),
              IconButton(
                tooltip: session.muted ? 'Unmute' : 'Mute',
                style: IconButton.styleFrom(
                  minimumSize: const Size(
                    AppConstants.minTouchDp,
                    AppConstants.minTouchDp,
                  ),
                ),
                onPressed: () async {
                  if (!settings.voiceEnabled) {
                    await ref
                        .read(settingsProvider.notifier)
                        .setVoiceEnabled(true);
                    ref.read(mapSessionProvider.notifier).setMuted(false);
                    return;
                  }
                  ref
                      .read(mapSessionProvider.notifier)
                      .setMuted(!session.muted);
                },
                icon: Icon(
                  session.muted || !settings.voiceEnabled
                      ? Icons.volume_off
                      : Icons.volume_up,
                ),
              ),
              if (arrived)
                FilledButton(
                  onPressed: () =>
                      ref.read(mapSessionProvider.notifier).clearArrived(),
                  child: const Text('Done'),
                )
              else
                IconButton(
                  tooltip: 'Stop',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(
                      AppConstants.minTouchDp,
                      AppConstants.minTouchDp,
                    ),
                  ),
                  onPressed: () => _confirmStop(context, ref),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmStop(BuildContext context, WidgetRef ref) async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit navigation?'),
        content: const Text('Turn-by-turn will stop. Your parked location is saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (stop == true && context.mounted) {
      ref.read(mapSessionProvider.notifier).stopNavigation();
    }
  }

  Widget _stat(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
