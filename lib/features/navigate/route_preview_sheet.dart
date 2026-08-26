import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/maneuver.dart';
import '../../models/place.dart';
import '../../models/route_plan.dart';
import '../../providers/app_providers.dart';
import '../search/search_sheet.dart';

/// Peekable route preview. Parent must be [Positioned] to the stack edges
/// (`left/right/bottom/top: 0`) so peek/mid/max fractions are of the map.
class RoutePreviewBar extends ConsumerStatefulWidget {
  const RoutePreviewBar({super.key, this.onFitRoute});

  static const peekSize = 0.22;
  static const midSize = 0.38;
  static const maxSize = 0.88;

  final VoidCallback? onFitRoute;

  @override
  ConsumerState<RoutePreviewBar> createState() => _RoutePreviewBarState();
}

class _RoutePreviewBarState extends ConsumerState<RoutePreviewBar> {
  static const _peek = RoutePreviewBar.peekSize;
  static const _mid = RoutePreviewBar.midSize;
  static const _max = RoutePreviewBar.maxSize;

  final _sheet = DraggableScrollableController();

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _snapTo(double size) async {
    if (!_sheet.isAttached) return;
    await _sheet.animateTo(
      size,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(mapSessionProvider);
    final dest = session.destination;
    if (dest == null || session.phase != NavPhase.preview) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final route = session.route;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
            controller: _sheet,
            expand: true,
            initialChildSize: _peek,
            minChildSize: _peek,
            maxChildSize: _max,
            snap: true,
            snapSizes: const [_peek, _mid, _max],
            snapAnimationDuration: const Duration(milliseconds: 220),
            shouldCloseOnMinExtent: false,
            builder: (context, scrollController) {
              return Material(
                elevation: 10,
                color: theme.colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: SafeArea(
                  top: false,
                  child: CustomScrollView(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _PeekHeader(
                          destName: dest.name,
                          isFavorite: ref
                              .watch(favoritesListProvider)
                              .any((p) => p.id == dest.id),
                          routing: session.routing,
                          routeError: session.routeError,
                          route: route,
                          metric: settings.metricUnits,
                          onGo: route == null || session.routing
                              ? null
                              : () => ref
                                  .read(mapSessionProvider.notifier)
                                  .startNavigation(),
                          onFavoriteSelected: (value) =>
                              _onFavoriteSelected(dest, value),
                          favoriteBuilder: (_) => _favoriteItems(dest.id),
                          onClose: () => ref
                              .read(mapSessionProvider.notifier)
                              .cancelPreview(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _MidSection(
                          destSubtitle: dest.subtitle,
                          mode: session.mode,
                          vias: session.vias,
                          alternatives: session.alternatives,
                          routeIndex: session.routeIndex,
                          routing: session.routing,
                          routeError: session.routeError,
                          onMode: (m) =>
                              ref.read(mapSessionProvider.notifier).setMode(m),
                          onRemoveVia: (i) => ref
                              .read(mapSessionProvider.notifier)
                              .removeVia(i),
                          onSelectAlt: (i) => ref
                              .read(mapSessionProvider.notifier)
                              .selectAlternative(i),
                          onAddStop: _addStop,
                          onFitRoute: widget.onFitRoute,
                          onSteps: () => _snapTo(_max),
                          onExportGpx: route == null
                              ? null
                              : () => _exportGpx(route),
                        ),
                      ),
                      if (route != null &&
                          !session.routing &&
                          route.instructions.isNotEmpty)
                        ..._stepsSlivers(theme, route, settings.metricUnits),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
              );
            },
      ),
    );
  }

  List<PopupMenuEntry<String>> _favoriteItems(String destId) {
    final favs = ref.read(favoritesRepositoryProvider);
    final folders = ref.read(foldersListProvider);
    return [
      if (favs.isFavorite(destId))
        const PopupMenuItem(
          value: 'remove',
          child: Text('Remove favorite'),
        ),
      for (final f in folders)
        PopupMenuItem(
          value: f,
          child: Text('Save in $f'),
        ),
    ];
  }

  Future<void> _onFavoriteSelected(Place dest, String value) async {
    final favs = ref.read(favoritesRepositoryProvider);
    if (value == 'remove') {
      await favs.removeFavorite(dest.id);
      ref.read(favoritesListProvider.notifier).state = favs.loadFavorites();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${dest.name}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await favs.addFavorite(dest);
              ref.read(favoritesListProvider.notifier).state =
                  favs.loadFavorites();
            },
          ),
        ),
      );
      return;
    }
    await favs.addFavorite(dest, group: value);
    ref.read(foldersListProvider.notifier).state = favs.loadFolders();
    ref.read(favoritesListProvider.notifier).state = favs.loadFavorites();
  }

  Future<void> _addStop() async {
    final dest = ref.read(mapSessionProvider).destination;
    if (dest == null) return;
    final bias =
        ref.read(locationServiceProvider).lastFix?.position ?? dest.latLng;
    final place = await showSearchSheet(context, bias: bias);
    if (place != null) {
      await ref.read(mapSessionProvider.notifier).addVia(place);
    }
  }

  Future<void> _exportGpx(RoutePlan route) async {
    final gpx = ref.read(gpxServiceProvider);
    final xml = gpx.exportRoute(route);
    final file = await gpx.writeToDisk(
      'route_${route.destination.name}',
      xml,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${file.path}')),
    );
  }

  List<Widget> _stepsSlivers(ThemeData theme, RoutePlan route, bool metric) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Steps',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      SliverList.separated(
        itemCount: route.instructions.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final step = route.instructions[i];
          return ListTile(
            leading: Icon(
              Maneuver.icon(type: step.type, modifier: step.modifier),
            ),
            title: Text(step.text),
            subtitle: Text(
              formatDistanceMeters(step.distanceMeters, metric: metric),
            ),
          );
        },
      ),
    ];
  }
}

class _PeekHeader extends StatelessWidget {
  const _PeekHeader({
    required this.destName,
    required this.isFavorite,
    required this.routing,
    required this.routeError,
    required this.route,
    required this.metric,
    required this.onGo,
    required this.onFavoriteSelected,
    required this.favoriteBuilder,
    required this.onClose,
  });

  final String destName;
  final bool isFavorite;
  final bool routing;
  final String? routeError;
  final RoutePlan? route;
  final bool metric;
  final VoidCallback? onGo;
  final ValueChanged<String> onFavoriteSelected;
  final PopupMenuItemBuilder<String> favoriteBuilder;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final handleTheme = theme.bottomSheetTheme;
    final handleSize = handleTheme.dragHandleSize ?? const Size(32, 4);
    final handleColor = handleTheme.dragHandleColor ??
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 16,
            child: Center(
              child: Semantics(
                label: 'Drag handle',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(handleSize.height / 2),
                  ),
                  child: SizedBox(
                    width: handleSize.width,
                    height: handleSize.height,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  destName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Favorite',
                icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                onSelected: onFavoriteSelected,
                itemBuilder: favoriteBuilder,
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 4),
            child: Row(
              children: [
                Expanded(child: _PeekStats(
                  routing: routing,
                  routeError: routeError,
                  route: route,
                  metric: metric,
                )),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onGo,
                  icon: const Icon(Icons.navigation, size: 18),
                  label: const Text('Go'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 40),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeekStats extends StatelessWidget {
  const _PeekStats({
    required this.routing,
    required this.routeError,
    required this.route,
    required this.metric,
  });

  final bool routing;
  final String? routeError;
  final RoutePlan? route;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (routing) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (routeError != null) {
      return Text(
        routeError!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
    if (route == null) {
      return Text(
        'No route',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final eta = DateTime.now().add(
      Duration(seconds: route!.durationSeconds.round()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${route!.formatDuration()} · ${formatEtaClock(eta)}',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          route!.formatDistance(metric: metric),
          style: theme.textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MidSection extends StatelessWidget {
  const _MidSection({
    required this.destSubtitle,
    required this.mode,
    required this.vias,
    required this.alternatives,
    required this.routeIndex,
    required this.routing,
    required this.routeError,
    required this.onMode,
    required this.onRemoveVia,
    required this.onSelectAlt,
    required this.onAddStop,
    required this.onFitRoute,
    required this.onSteps,
    required this.onExportGpx,
  });

  final String destSubtitle;
  final TravelMode mode;
  final List<Place> vias;
  final List<RoutePlan> alternatives;
  final int routeIndex;
  final bool routing;
  final String? routeError;
  final ValueChanged<TravelMode> onMode;
  final ValueChanged<int> onRemoveVia;
  final ValueChanged<int> onSelectAlt;
  final VoidCallback onAddStop;
  final VoidCallback? onFitRoute;
  final VoidCallback onSteps;
  final VoidCallback? onExportGpx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (destSubtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: Text(
                destSubtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<TravelMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: TravelMode.walk,
                  icon: Icon(Icons.directions_walk),
                  tooltip: 'Walk',
                ),
                ButtonSegment(
                  value: TravelMode.bike,
                  icon: Icon(Icons.directions_bike),
                  tooltip: 'Bike',
                ),
                ButtonSegment(
                  value: TravelMode.drive,
                  icon: Icon(Icons.directions_car),
                  tooltip: 'Drive',
                ),
                ButtonSegment(
                  value: TravelMode.truck,
                  icon: Icon(Icons.local_shipping),
                  tooltip: 'Truck',
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) => onMode(s.first),
            ),
          ),
          if (vias.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < vias.length; i++)
                  InputChip(
                    label: Text(vias[i].name),
                    onDeleted: () => onRemoveVia(i),
                  ),
              ],
            ),
          ],
          if (!routing && routeError == null && alternatives.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                primary: false,
                itemCount: alternatives.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final alt = alternatives[i];
                  return ChoiceChip(
                    selected: i == routeIndex,
                    label: Text(
                      '${alt.label} · ${formatDurationSeconds(alt.durationSeconds)}',
                    ),
                    onSelected: (_) => onSelectAlt(i),
                  );
                },
              ),
            ),
          ],
          Row(
            children: [
              IconButton(
                tooltip: 'Add stop',
                onPressed: onAddStop,
                icon: const Icon(Icons.add_location_alt_outlined),
              ),
              IconButton(
                tooltip: 'Fit route',
                onPressed: onFitRoute,
                icon: const Icon(Icons.zoom_out_map),
              ),
              IconButton(
                tooltip: 'Steps',
                onPressed: onSteps,
                icon: const Icon(Icons.list),
              ),
              IconButton(
                tooltip: 'Export GPX',
                onPressed: onExportGpx,
                icon: const Icon(Icons.ios_share),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
