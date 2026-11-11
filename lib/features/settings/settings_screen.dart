import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants.dart';
import '../../models/app_settings.dart';
import '../../models/place.dart';
import '../../providers/app_providers.dart';
import '../search/search_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final favs = ref.watch(favoritesListProvider);
    final home = favs.where((p) => p.role == PlaceRole.home);
    final work = favs.where((p) => p.role == PlaceRole.work);
    final n = ref.watch(settingsProvider.notifier);
    final nightActive = ref.watch(nightDrivingActiveProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionTitle('Map'),
          _enumTile<ThemePreference>(
            title: 'Theme',
            value: settings.theme,
            values: ThemePreference.values,
            label: (v) => switch (v) {
              ThemePreference.system => 'System',
              ThemePreference.light => 'Light',
              ThemePreference.dark => 'Dark',
            },
            onChanged: n.setTheme,
            // Night driving wins over the theme; say so instead of leaving
            // "Light" looking broken after sunset.
            subtitle: nightActive && settings.theme != ThemePreference.dark
                ? 'Dark right now: night driving is on'
                : null,
          ),
          _enumTile<MapStylePreference>(
            title: 'Map style',
            value: settings.mapStyle,
            values: MapStylePreference.values,
            label: (v) => switch (v) {
              MapStylePreference.auto => 'Auto',
              MapStylePreference.light => 'Street',
              MapStylePreference.dark => 'Dark',
              MapStylePreference.topo => 'Topographic',
              MapStylePreference.cycle => 'Cycling',
            },
            onChanged: n.setMapStyle,
          ),
          _enumTile<NightDriving>(
            title: 'Night driving',
            value: settings.nightDriving,
            values: NightDriving.values,
            label: (v) => switch (v) {
              NightDriving.off => 'Off',
              NightDriving.auto => 'Auto (sunset)',
              NightDriving.on => 'Always',
            },
            onChanged: n.setNightDriving,
            subtitle: switch (settings.nightDriving) {
              NightDriving.auto => nightActive
                  ? 'On now (after sunset): dark map and theme'
                  : 'Dark map and theme after sunset',
              NightDriving.on => 'Dark map and theme all the time',
              NightDriving.off => null,
            },
          ),
          SwitchListTile(
            title: const Text('High contrast'),
            value: settings.highContrast,
            onChanged: n.setHighContrast,
          ),
          SwitchListTile(
            title: const Text('Speedometer'),
            value: settings.showSpeed,
            onChanged: n.setShowSpeed,
          ),
          SwitchListTile(
            title: const Text('Scale bar'),
            value: settings.showScaleBar,
            onChanged: n.setShowScaleBar,
          ),
          SwitchListTile(
            title: const Text('Lock map rotation'),
            subtitle: const Text('Disable pinch-rotate (easier on phones)'),
            value: settings.rotationLock,
            onChanged: n.setRotationLock,
          ),
          const _SectionTitle('Navigation'),
          SwitchListTile(
            title: const Text('Metric units'),
            subtitle: Text(settings.metricUnits ? 'km / m' : 'mi / ft'),
            value: settings.metricUnits,
            onChanged: n.setMetricUnits,
          ),
          SwitchListTile(
            title: const Text('Course up while navigating'),
            subtitle: const Text('Applies immediately on the next GPS fix'),
            value: settings.courseUp,
            onChanged: n.setCourseUp,
          ),
          SwitchListTile(
            title: const Text('Follow on start'),
            value: settings.followOnStart,
            onChanged: n.setFollowOnStart,
          ),
          SwitchListTile(
            title: const Text('Keep screen on'),
            value: settings.keepScreenOn,
            onChanged: n.setKeepScreenOn,
          ),
          SwitchListTile(
            title: const Text('Large HUD'),
            subtitle: const Text('Bigger turn distances while driving'),
            value: settings.largeHud,
            onChanged: n.setLargeHud,
          ),
          SwitchListTile(
            title: const Text('Haptics'),
            value: settings.haptics,
            onChanged: n.setHaptics,
          ),
          const _SectionTitle('Voice'),
          SwitchListTile(
            title: const Text('Voice guidance'),
            value: settings.voiceEnabled,
            onChanged: n.setVoiceEnabled,
          ),
          const _SectionTitle('Places'),
          ListTile(
            title: const Text('Home'),
            subtitle: Text(
              home.isEmpty ? 'Not set: tap to choose' : home.first.name,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final place = await showSearchSheet(context);
              if (place != null) {
                await ref.read(favoritesRepositoryProvider).setRole(
                      place.copyWith(role: PlaceRole.home, name: place.name),
                      PlaceRole.home,
                    );
                ref.read(favoritesListProvider.notifier).state =
                    ref.read(favoritesRepositoryProvider).loadFavorites();
              }
            },
          ),
          ListTile(
            title: const Text('Work'),
            subtitle: Text(
              work.isEmpty ? 'Not set: tap to choose' : work.first.name,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final place = await showSearchSheet(context);
              if (place != null) {
                await ref
                    .read(favoritesRepositoryProvider)
                    .setRole(place, PlaceRole.work);
                ref.read(favoritesListProvider.notifier).state =
                    ref.read(favoritesRepositoryProvider).loadFavorites();
              }
            },
          ),
          ListTile(
            title: const Text('New bookmark folder'),
            trailing: const Icon(Icons.create_new_folder_outlined),
            onTap: () async {
              final controller = TextEditingController();
              final name = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Folder name'),
                  content: TextField(controller: controller, autofocus: true),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(ctx, controller.text.trim()),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              );
              if (name != null && name.isNotEmpty) {
                await ref.read(favoritesRepositoryProvider).addFolder(name);
                ref.read(foldersListProvider.notifier).state =
                    ref.read(favoritesRepositoryProvider).loadFolders();
              }
            },
          ),
          const _SectionTitle('Advanced'),
          _enumTile<int>(
            title: 'Map cache limit',
            value: AppSettings.tileCacheLimitChoicesMb
                    .contains(settings.tileCacheLimitMb)
                ? settings.tileCacheLimitMb
                : 500,
            values: AppSettings.tileCacheLimitChoicesMb,
            label: (mb) => mb == 0
                ? 'No limit'
                : mb >= 1000
                    ? '${mb ~/ 1000} GB'
                    : '$mb MB',
            onChanged: (mb) async {
              await n.update(settings.copyWith(tileCacheLimitMb: mb));
              final tiles = ref.read(tileCacheServiceProvider);
              tiles.maxCacheBytes = mb * 1024 * 1024;
              await tiles.trimToCap();
            },
          ),
          const _CacheUsageTile(),
          ListTile(
            title: const Text('CARTO basemap key'),
            subtitle: Text(
              settings.cartoApiKey.isEmpty
                  ? 'Optional. Street/Dark use OpenStreetMap tiles; add a free '
                      'key from carto.com/basemaps/apikey for CARTO Voyager / '
                      'Dark Matter and offline downloads'
                  : 'Set — using CARTO Voyager / Dark Matter',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final controller =
                  TextEditingController(text: settings.cartoApiKey);
              final value = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('CARTO basemap key'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Key from carto.com/basemaps/apikey',
                    ),
                    autofocus: true,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, ''),
                      child: const Text('Clear'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(ctx, controller.text.trim()),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (value != null) {
                await n.setCartoApiKey(value);
              }
            },
          ),
          ListTile(
            title: const Text('Custom routing server'),
            subtitle: Text(
              settings.customRoutingUrl.isEmpty
                  ? 'FOSSGIS OSRM + public Valhalla for truck'
                  : settings.customRoutingUrl,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final controller =
                  TextEditingController(text: settings.customRoutingUrl);
              final value = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Routing endpoint'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText:
                          'https://routing.example/route/v1/driving or Valhalla base',
                    ),
                    autofocus: true,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, ''),
                      child: const Text('Clear'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(ctx, controller.text.trim()),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (value != null) {
                await n.setCustomRoutingUrl(value);
              }
            },
          ),
          const _SectionTitle('About'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final v = snap.data;
              return ListTile(
                title: const Text(AppConstants.appName),
                subtitle: Text(
                  v == null
                      ? 'Open-source OSM navigation'
                      : 'Version ${v.version} (${v.buildNumber})\n'
                          'OpenStreetMap · Photon · OSRM · Valhalla · CARTO',
                ),
                isThreeLine: true,
              );
            },
          ),
          const ListTile(
            title: Text('Data'),
            subtitle: Text(
              'Map data © OpenStreetMap contributors. '
              'Search via Photon (Komoot). Routing via FOSSGIS OSRM and '
              'public Valhalla. Tiles © CARTO, OpenTopoMap, CyclOSM.',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }

  Widget _enumTile<T>({
    required String title,
    required T value,
    required List<T> values,
    required String Function(T) label,
    required Future<void> Function(T) onChanged,
    String? subtitle,
  }) {
    // The dropdown already shows the current value; repeating it as a
    // subtitle only made every row taller.
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: DropdownButton<T>(
        value: value,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        items: values
            .map(
              (t) => DropdownMenuItem(
                value: t,
                child: Text(label(t)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Shows how much disk the tile cache uses and lets the user drop browsed
/// tiles (e.g. when the map looks outdated). Saved offline areas are kept.
class _CacheUsageTile extends ConsumerStatefulWidget {
  const _CacheUsageTile();

  @override
  ConsumerState<_CacheUsageTile> createState() => _CacheUsageTileState();
}

class _CacheUsageTileState extends ConsumerState<_CacheUsageTile> {
  Future<({int bytes, int tiles})>? _usage;
  bool _clearing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _usage ??= ref.read(tileCacheServiceProvider).cacheUsage();
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear browsed map tiles?'),
        content: const Text(
          'Tiles are downloaded again as you look at the map. '
          'Saved offline areas are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('cache_clear_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final tiles = ref.read(tileCacheServiceProvider);
    setState(() => _clearing = true);
    final r = await tiles.clearBrowsedTiles();
    if (!mounted) return;
    setState(() {
      _clearing = false;
      _usage = tiles.cacheUsage();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Freed ${(r.freedBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({int bytes, int tiles})>(
      future: _usage,
      builder: (context, snap) {
        final u = snap.data;
        return ListTile(
          key: const Key('cache_usage_tile'),
          title: Text(
            u == null
                ? 'Cached map tiles'
                : 'Cached map tiles: '
                      '${(u.bytes / (1024 * 1024)).toStringAsFixed(1)} MB',
          ),
          subtitle: Text(
            u == null
                ? 'Measuring…'
                : '${u.tiles} tiles. Tiles older than 7 days refresh as you '
                      'view them; over the limit the oldest are removed. '
                      'Saved offline areas are kept.',
          ),
          trailing: TextButton(
            key: const Key('cache_clear'),
            onPressed: _clearing || u == null || u.tiles == 0 ? null : _clear,
            child: _clearing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Clear'),
          ),
        );
      },
    );
  }
}
