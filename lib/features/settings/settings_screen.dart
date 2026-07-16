import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants.dart';
import '../../models/app_settings.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionTitle('Appearance'),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(settings.theme.name),
            trailing: DropdownButton<ThemePreference>(
              value: settings.theme,
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).setTheme(v);
                }
              },
              items: ThemePreference.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.name),
                    ),
                  )
                  .toList(),
            ),
          ),
          ListTile(
            title: const Text('Map style'),
            subtitle: Text(settings.mapStyle.name),
            trailing: DropdownButton<MapStylePreference>(
              value: settings.mapStyle,
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).setMapStyle(v);
                }
              },
              items: MapStylePreference.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.name),
                    ),
                  )
                  .toList(),
            ),
          ),
          const _SectionTitle('Navigation'),
          SwitchListTile(
            title: const Text('Metric units'),
            subtitle: Text(settings.metricUnits ? 'km / m' : 'mi / ft'),
            value: settings.metricUnits,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setMetricUnits(v),
          ),
          SwitchListTile(
            title: const Text('Course up while navigating'),
            subtitle: const Text('Rotate map in direction of travel'),
            value: settings.courseUp,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setCourseUp(v),
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
                          'OpenStreetMap · Photon · OSRM · CARTO',
                ),
                isThreeLine: true,
              );
            },
          ),
          const ListTile(
            title: Text('Data'),
            subtitle: Text(
              'Map data © OpenStreetMap contributors. '
              'Search via Photon (Komoot). Routing via FOSSGIS OSRM. '
              'Tiles © CARTO.',
            ),
            isThreeLine: true,
          ),
        ],
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
