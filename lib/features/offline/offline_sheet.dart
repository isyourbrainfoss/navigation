import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../providers/app_providers.dart';

Future<void> showOfflineSheet(
  BuildContext context, {
  required LatLng center,
  required String styleKey,
  required String urlTemplate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => OfflineSheet(
      center: center,
      styleKey: styleKey,
      urlTemplate: urlTemplate,
    ),
  );
}

class OfflineSheet extends ConsumerStatefulWidget {
  const OfflineSheet({
    super.key,
    required this.center,
    required this.styleKey,
    required this.urlTemplate,
  });

  final LatLng center;
  final String styleKey;
  final String urlTemplate;

  @override
  ConsumerState<OfflineSheet> createState() => _OfflineSheetState();
}

class _OfflineSheetState extends ConsumerState<OfflineSheet> {
  double _radiusKm = 10;
  final _nameController = TextEditingController(text: 'Map area');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineProvider);
    final cache = ref.watch(tileCacheServiceProvider);
    final radiusM = _radiusKm * 1000;
    final estimate = cache.estimateTiles(
      center: widget.center,
      radiusMeters: radiusM,
    );
    // Rough ~15 KB average per tile.
    final estBytes = estimate * 15 * 1024;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              'Offline maps',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Download tiles around the map center for offline browsing. '
              'Routing still needs a network connection.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),
            Text('Radius: ${_radiusKm.toStringAsFixed(0)} km'),
            Slider(
              value: _radiusKm,
              min: 5,
              max: 50,
              divisions: 9,
              label: '${_radiusKm.round()} km',
              onChanged: offline.downloading
                  ? null
                  : (v) => setState(() => _radiusKm = v),
            ),
            Text(
              '≈ $estimate tiles · ~${formatBytes(estBytes)} '
              '(z${AppConstants.offlineMinZoom}–${AppConstants.offlineMaxZoom})',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (offline.progress != null) ...[
              LinearProgressIndicator(value: offline.progress!.fraction),
              const SizedBox(height: 6),
              Text(
                '${offline.progress!.done} / ${offline.progress!.total} · '
                '${formatBytes(offline.progress!.bytes)}',
              ),
              const SizedBox(height: 8),
            ],
            if (offline.error != null)
              Text(
                offline.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: offline.downloading
                        ? null
                        : () async {
                            await ref.read(offlineProvider.notifier).download(
                                  name: _nameController.text.trim().isEmpty
                                      ? 'Map area'
                                      : _nameController.text.trim(),
                                  center: widget.center,
                                  radiusMeters: radiusM,
                                  styleKey: widget.styleKey,
                                  urlTemplate: widget.urlTemplate,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Download finished'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.download),
                    label: Text(
                      offline.downloading ? 'Downloading…' : 'Download area',
                    ),
                  ),
                ),
                if (offline.downloading) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(offlineProvider.notifier).cancel(),
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Saved regions',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (offline.regions.isEmpty)
              Text(
                'No offline regions yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...offline.regions.map(
                (r) => Card(
                  child: ListTile(
                    title: Text(r.name),
                    subtitle: Text(
                      '${formatRadiusKm(r.radiusMeters)} · '
                      '${r.tileCount} tiles · ${formatBytes(r.bytes)}\n'
                      '${r.status.name}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref.read(offlineProvider.notifier).delete(r.id),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
