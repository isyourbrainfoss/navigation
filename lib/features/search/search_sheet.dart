import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/geometry.dart';
import '../../models/place.dart';
import '../../providers/app_providers.dart';
import '../../services/search_service.dart';

Future<Place?> showSearchSheet(
  BuildContext context, {
  LatLng? bias,
  bool alongRoute = false,
}) {
  return Navigator.of(context).push<Place>(
    MaterialPageRoute(
      builder: (_) => SearchSheet(bias: bias, alongRoute: alongRoute),
    ),
  );
}

class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({super.key, this.bias, this.alongRoute = false});

  final LatLng? bias;
  final bool alongRoute;

  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<SearchSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: AppConstants.searchDebounceMs),
      () {
        final route = ref.read(mapSessionProvider).route;
        if (widget.alongRoute && route != null && value.trim().isNotEmpty) {
          ref.read(searchProvider.notifier).searchAlongRoute(value, route: route);
        } else {
          ref.read(searchProvider.notifier).search(value, bias: widget.bias);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final favorites = ref.watch(favoritesListProvider);
    final recents = ref.watch(recentsListProvider);
    final theme = Theme.of(context);

    final home = favorites.where((p) => p.role == PlaceRole.home);
    final work = favorites.where((p) => p.role == PlaceRole.work);
    final parked = favorites.where((p) => p.role == PlaceRole.parked);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.alongRoute
                ? 'Search along route'
                : 'Search places or 52.52, 13.40',
            border: InputBorder.none,
            suffixIcon: search.query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchProvider.notifier).clear();
                    },
                  ),
          ),
          onChanged: _onQuery,
          onSubmitted: (v) {
            if (widget.alongRoute &&
                ref.read(mapSessionProvider).route != null) {
              ref.read(searchProvider.notifier).searchAlongRoute(
                    v,
                    route: ref.read(mapSessionProvider).route!,
                  );
            } else {
              ref.read(searchProvider.notifier).search(v, bias: widget.bias);
            }
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            if (widget.bias != null)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final c in PoiCategory.all)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(c.label),
                          onPressed: () => ref
                              .read(searchProvider.notifier)
                              .searchCategory(c, bias: widget.bias!),
                        ),
                      ),
                  ],
                ),
              ),
            if (search.loading) const LinearProgressIndicator(minHeight: 2),
            if (search.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  search.error!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            Expanded(
              child: search.query.trim().isEmpty
                  ? _EmptySearchLists(
                      favorites: favorites,
                      recents: recents,
                      home: home.isEmpty ? null : home.first,
                      work: work.isEmpty ? null : work.first,
                      parked: parked.isEmpty ? null : parked.first,
                      myLocation: widget.bias,
                      onPick: (p) => Navigator.pop(context, p),
                    )
                  : !search.loading && search.results.isEmpty
                      ? const _NoPlacesEmpty()
                      : ListView.separated(
                          itemCount: search.results.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final place = search.results[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.place_outlined),
                              ),
                              title: Text(place.name),
                              subtitle: Text(
                                [
                                  if (widget.bias != null)
                                    formatDistanceMeters(
                                      GeoMath.haversineMeters(
                                        widget.bias!,
                                        place.latLng,
                                      ),
                                      metric: true,
                                    ),
                                  if (place.subtitle.isNotEmpty)
                                    place.subtitle,
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.pop(context, place),
                            );
                          },
                        ),
            ),
          ],
        ),
    );
  }
}

class _NoPlacesEmpty extends StatelessWidget {
  const _NoPlacesEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _EmptyPlacesPainter(
                accent: scheme.primary,
                muted: scheme.outline,
                surface: scheme.surface,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No places — try coordinates or long-press the map',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlacesPainter extends CustomPainter {
  const _EmptyPlacesPainter({
    required this.accent,
    required this.muted,
    required this.surface,
  });

  final Color accent;
  final Color muted;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..color = muted.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(c, size.shortestSide * 0.46, ring);
    canvas.drawCircle(c, size.shortestSide * 0.32, ring);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, size.height * 0.82),
        width: 36,
        height: 10,
      ),
      Paint()..color = muted.withValues(alpha: 0.28),
    );

    final pinTop = Offset(c.dx, c.dy - 8);
    final pin = ui.Path()
      ..moveTo(pinTop.dx, pinTop.dy + 28)
      ..cubicTo(
        pinTop.dx - 18,
        pinTop.dy + 10,
        pinTop.dx - 16,
        pinTop.dy - 14,
        pinTop.dx,
        pinTop.dy - 14,
      )
      ..cubicTo(
        pinTop.dx + 16,
        pinTop.dy - 14,
        pinTop.dx + 18,
        pinTop.dy + 10,
        pinTop.dx,
        pinTop.dy + 28,
      )
      ..close();
    canvas.drawPath(pin, Paint()..color = accent);
    canvas.drawCircle(
      Offset(pinTop.dx, pinTop.dy - 4),
      6,
      Paint()..color = surface,
    );
  }

  @override
  bool shouldRepaint(covariant _EmptyPlacesPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.muted != muted ||
        oldDelegate.surface != surface;
  }
}

class _EmptySearchLists extends StatelessWidget {
  const _EmptySearchLists({
    required this.favorites,
    required this.recents,
    required this.onPick,
    this.home,
    this.work,
    this.parked,
    this.myLocation,
  });

  final List<Place> favorites;
  final List<Place> recents;
  final Place? home;
  final Place? work;
  final Place? parked;
  final LatLng? myLocation;
  final ValueChanged<Place> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (myLocation != null)
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('My location'),
            onTap: () => onPick(
              Place.fromLatLng(myLocation!, name: 'My location'),
            ),
          ),
        if (home != null)
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            subtitle: Text(home!.name),
            onTap: () => onPick(home!),
          ),
        if (work != null)
          ListTile(
            leading: const Icon(Icons.work_outline),
            title: const Text('Work'),
            subtitle: Text(work!.name),
            onTap: () => onPick(work!),
          ),
        if (parked != null)
          ListTile(
            leading: const Icon(Icons.local_parking),
            title: const Text('Parked car'),
            subtitle: Text(parked!.name),
            onTap: () => onPick(parked!),
          ),
        if (favorites.isNotEmpty) ...[
          const _SectionHeader(label: 'Favorites', icon: Icons.star_outline),
          ...favorites.map(
            (p) => ListTile(
              leading: const Icon(Icons.star),
              title: Text(p.name),
              subtitle: p.group.isEmpty
                  ? (p.subtitle.isEmpty ? null : Text(p.subtitle))
                  : Text(p.group),
              onTap: () => onPick(p),
            ),
          ),
        ],
        if (recents.isNotEmpty) ...[
          const _SectionHeader(label: 'Recent', icon: Icons.history),
          ...recents.map(
            (p) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(p.name),
              subtitle: p.subtitle.isEmpty ? null : Text(p.subtitle),
              onTap: () => onPick(p),
            ),
          ),
        ],
        if (favorites.isEmpty && recents.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Search for a place, paste coordinates, or long-press the map.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
