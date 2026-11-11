import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/maneuver.dart';
import '../../providers/app_providers.dart';
import '../map/widgets/glass.dart';
import 'instruction_sheet.dart';
import 'lane_strip.dart';

/// Sizes for the guidance chrome. Kept tight so that on a phone the
/// maneuver card, ETA bar and off-route banner leave most of the map, and
/// the position puck, visible.
abstract final class GuidanceSizes {
  static const iconBox = 56.0;
  static const icon = 36.0;
  static const distanceFont = 34.0;
  static const instructionFont = 18.0;

  /// Mute / Stop in the ETA bar and Keep route: Material's 48 dp minimum.
  static const barButton = 48.0;
}

class GuidanceBanner extends ConsumerWidget {
  const GuidanceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(mapSessionProvider);
    final settings = ref.watch(settingsProvider);
    // Rebuild on each fix so the ETA clock stays current.
    ref.watch(locationFixProvider);
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        key: const Key('maneuver_icon_box'),
                        width: GuidanceSizes.iconBox,
                        height: GuidanceSizes.iconBox,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          arrived
                              ? Icons.check_rounded
                              : Maneuver.icon(
                                  type: step?.type,
                                  modifier: step?.modifier,
                                ),
                          size: GuidanceSizes.icon,
                          color: onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                  height: 1.0,
                                  fontSize: GuidanceSizes.distanceFont,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            Text(
                              arrived
                                  ? 'You have arrived'
                                  : (step?.text ?? 'Continue'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: onPrimary,
                                fontSize: GuidanceSizes.instructionFont,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                            if (!arrived && approaching) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
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
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  thenLine(thenNext.text),
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
                    const SizedBox(height: 6),
                    LaneStrip(lanes: step.lanes),
                  ],
                  if (session.rerouting)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
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
        const SizedBox(height: 6),
        Glass(
          key: const Key('guidance_eta_bar'),
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          child: Row(
            children: [
              // Wraps instead of overflowing on narrow phones. Current speed
              // lives in the speed capsule on the map, not here as well.
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 2,
                  children: [
                    _stat(
                      theme,
                      Icons.schedule,
                      '${formatDurationSeconds(remainingS)} · '
                      '${formatEtaClock(eta)}',
                    ),
                    _stat(
                      theme,
                      Icons.straighten,
                      formatDistanceMeters(
                        remainingM,
                        metric: settings.metricUnits,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: session.muted ? 'Unmute' : 'Mute',
                style: IconButton.styleFrom(
                  minimumSize: const Size(
                    GuidanceSizes.barButton,
                    GuidanceSizes.barButton,
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
                      GuidanceSizes.barButton,
                      GuidanceSizes.barButton,
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

/// "Then turn left onto Storgata": lowercases the instruction's first letter
/// and drops a leading "At the end of the road, " style clause so the useful
/// part fits on one line.
String thenLine(String instruction) {
  var t = instruction.trim();
  final comma = t.indexOf(', ');
  if (comma > 0 && comma < 40 && RegExp(r'^(At|In|After|On) ').hasMatch(t)) {
    t = t.substring(comma + 2);
  }
  if (t.isEmpty) return 'Then continue';
  final first = t[0];
  final second = t.length > 1 ? t[1] : '';
  // Keep acronyms/names like "E6" or "Ring 3" as they are.
  final lower = RegExp(r'[a-zæøåäöü]').hasMatch(second)
      ? first.toLowerCase()
      : first;
  return 'Then $lower${t.substring(1)}';
}

/// One-line off-route notice with a high-contrast "Keep route" button.
class OffRouteBanner extends StatelessWidget {
  const OffRouteBanner({
    super.key,
    required this.rerouting,
    required this.onKeepRoute,
  });

  final bool rerouting;
  final VoidCallback onKeepRoute;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('off_route_banner'),
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
        child: Row(
          children: [
            Icon(
              Icons.wrong_location_outlined,
              size: 20,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                rerouting ? 'Recalculating…' : 'Off route · finding a new path',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            // Filled, so it reads on the tinted banner (a text button in the
            // same hue was hard to see).
            FilledButton(
              key: const Key('off_route_stay'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.onTertiaryContainer,
                foregroundColor: scheme.tertiaryContainer,
                minimumSize: const Size(64, GuidanceSizes.barButton),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: onKeepRoute,
              child: const Text('Keep route'),
            ),
          ],
        ),
      ),
    );
  }
}
