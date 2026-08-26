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
          ),
          _enumTile<MapStylePreference>(
            title: 'Map style',
            value: settings.mapStyle,
            values: MapStylePreference.values,
            label: (v) => switch (v) {
              MapStylePreference.auto => 'Auto',
              MapStylePreference.light => 'Voyager',
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
            subtitle: Text(home.isEmpty ? 'Not set' : home.first.name),
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
            subtitle: Text(work.isEmpty ? 'Not set' : work.first.name),
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
          ListTile(
            title: const Text('Custom routing server'),
            subtitle: Text(
              settings.customRoutingUrl.isEmpty
                  ? 'FOSSGIS OSRM + public Valhalla for truck'
                  : settings.customRoutingUrl,
            ),
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
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(label(value)),
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
