import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/route_plan.dart';
import '../../providers/app_providers.dart';

class RoutePreviewBar extends ConsumerWidget {
  const RoutePreviewBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(mapSessionProvider);
    final settings = ref.watch(settingsProvider);
    final dest = session.destination;
    if (dest == null || session.phase != NavPhase.preview) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final route = session.route;

    return Material(
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dest.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Favorite',
                    onPressed: () async {
                      final favs = ref.read(favoritesRepositoryProvider);
                      final wasFav = favs.isFavorite(dest.id);
                      if (wasFav) {
                        await favs.removeFavorite(dest.id);
                      } else {
                        await favs.addFavorite(dest);
                      }
                      ref.read(favoritesListProvider.notifier).state =
                          favs.loadFavorites();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              wasFav
                                  ? 'Removed from favorites'
                                  : 'Added to favorites',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      ref.watch(favoritesListProvider).any((p) => p.id == dest.id)
                          ? Icons.star
                          : Icons.star_border,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () =>
                        ref.read(mapSessionProvider.notifier).stopNavigation(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (dest.subtitle.isNotEmpty)
                Text(
                  dest.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 12),
              SegmentedButton<TravelMode>(
                segments: const [
                  ButtonSegment(
                    value: TravelMode.walk,
                    label: Text('Walk'),
                    icon: Icon(Icons.directions_walk),
                  ),
                  ButtonSegment(
                    value: TravelMode.drive,
                    label: Text('Drive'),
                    icon: Icon(Icons.directions_car),
                  ),
                ],
                selected: {session.mode},
                onSelectionChanged: (s) {
                  ref.read(mapSessionProvider.notifier).setMode(s.first);
                },
              ),
              const SizedBox(height: 12),
              if (session.routing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (session.routeError != null)
                Text(
                  session.routeError!,
                  style: TextStyle(color: theme.colorScheme.error),
                )
              else if (route != null)
                Row(
                  children: [
                    Icon(Icons.schedule, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      route.formatDuration(),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.straighten,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      route.formatDistance(metric: settings.metricUnits),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: route == null || session.routing
                    ? null
                    : () => ref
                        .read(mapSessionProvider.notifier)
                        .startNavigation(),
                icon: const Icon(Icons.navigation),
                label: const Text('Go'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
