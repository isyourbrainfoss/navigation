import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../models/place.dart';
import '../../providers/app_providers.dart';

Future<Place?> showSearchSheet(
  BuildContext context, {
  LatLng? bias,
}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => SearchSheet(bias: bias),
  );
}

class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({super.key, this.bias});

  final LatLng? bias;

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
        ref.read(searchProvider.notifier).search(value, bias: widget.bias);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchProvider);
    final favorites = ref.watch(favoritesListProvider);
    final recents = ref.watch(recentsListProvider);
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search places',
                prefixIcon: const Icon(Icons.search),
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
              onSubmitted: (v) => ref
                  .read(searchProvider.notifier)
                  .search(v, bias: widget.bias),
            ),
          ),
          if (search.loading)
            const LinearProgressIndicator(minHeight: 2),
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
                    onPick: (p) => Navigator.pop(context, p),
                  )
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
                        subtitle: place.subtitle.isEmpty
                            ? null
                            : Text(
                                place.subtitle,
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

class _EmptySearchLists extends StatelessWidget {
  const _EmptySearchLists({
    required this.favorites,
    required this.recents,
    required this.onPick,
  });

  final List<Place> favorites;
  final List<Place> recents;
  final ValueChanged<Place> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (favorites.isNotEmpty) ...[
          const _SectionHeader(label: 'Favorites', icon: Icons.star_outline),
          ...favorites.map(
            (p) => ListTile(
              leading: const Icon(Icons.star),
              title: Text(p.name),
              subtitle: p.subtitle.isEmpty ? null : Text(p.subtitle),
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
              'Search for a place, or long-press the map to navigate there.',
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
