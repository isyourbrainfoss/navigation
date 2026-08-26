import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/track.dart';
import '../../providers/app_providers.dart';

Future<void> showTracksSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => const TracksSheet(),
  );
}

class TracksSheet extends ConsumerStatefulWidget {
  const TracksSheet({super.key});

  @override
  ConsumerState<TracksSheet> createState() => _TracksSheetState();
}

class _TracksSheetState extends ConsumerState<TracksSheet> {
  final _pendingDeleteIds = <String>{};

  Future<void> _deleteWithUndo(SavedTrack track) async {
    setState(() => _pendingDeleteIds.add(track.id));
    final repo = ref.read(trackRepositoryProvider);
    final tracksNotifier = ref.read(savedTracksProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final reason = await messenger
        .showSnackBar(
          SnackBar(
            content: Text('Deleted ${track.name}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                if (mounted) {
                  setState(() => _pendingDeleteIds.remove(track.id));
                }
              },
            ),
          ),
        )
        .closed;
    if (reason == SnackBarClosedReason.action) return;
    await repo.delete(track.id);
    tracksNotifier.state = repo.load();
    if (mounted) {
      setState(() => _pendingDeleteIds.remove(track.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracks = ref
        .watch(savedTracksProvider)
        .where((t) => !_pendingDeleteIds.contains(t.id))
        .toList();
    final recorder = ref.watch(trackRecorderProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              'Tracks',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        if (recorder.recording) {
                          final saved = recorder.stop();
                          ref.read(isRecordingProvider.notifier).state = false;
                          if (saved != null) {
                            ref.read(trackRepositoryProvider).add(saved);
                            ref.read(savedTracksProvider.notifier).state =
                                ref.read(trackRepositoryProvider).load();
                          }
                        } else {
                          recorder.start();
                          ref.read(isRecordingProvider.notifier).state = true;
                        }
                      });
                    },
                    icon: Icon(recorder.recording ? Icons.stop : Icons.fiber_manual_record),
                    label: Text(recorder.recording ? 'Stop recording' : 'Record track'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const ['gpx', 'xml'],
                    );
                    if (result == null || result.files.single.path == null) {
                      return;
                    }
                    final xml =
                        await File(result.files.single.path!).readAsString();
                    final doc = ref.read(gpxServiceProvider).parse(xml);
                    if (doc.tracks.isNotEmpty) {
                      for (final t in doc.tracks) {
                        await ref.read(trackRepositoryProvider).add(t);
                      }
                      ref.read(savedTracksProvider.notifier).state =
                          ref.read(trackRepositoryProvider).load();
                      if (context.mounted) {
                        ref
                            .read(mapSessionProvider.notifier)
                            .setOverlayTrack(doc.tracks.first);
                        Navigator.pop(context);
                      }
                    } else if (doc.primaryLine.length >= 2) {
                      final fake = SavedTrack(
                        id: 'gpx_${DateTime.now().millisecondsSinceEpoch}',
                        name: doc.name,
                        createdAtMs: DateTime.now().millisecondsSinceEpoch,
                        points: [
                          for (final p in doc.primaryLine)
                            TrackPoint(
                              latitude: p.latitude,
                              longitude: p.longitude,
                              timestampMs: 0,
                            ),
                        ],
                      );
                      ref.read(mapSessionProvider.notifier).setOverlayTrack(fake);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.file_open),
                  label: const Text('Import GPX'),
                ),
              ],
            ),
            if (recorder.recording)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Recording · ${recorder.points.length} points · '
                  '${formatDistanceMeters(recorder.distanceMeters, metric: true)}',
                ),
              ),
            const SizedBox(height: 16),
            if (tracks.isEmpty)
              Text(
                'No saved tracks yet. Record a walk or import a GPX file.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...tracks.map(
                (t) => Card(
                  child: ListTile(
                    title: Text(t.name),
                    subtitle: Text(
                      '${formatDistanceMeters(t.distanceMeters, metric: true)} · '
                      '${t.points.length} pts',
                    ),
                    onTap: () {
                      ref.read(mapSessionProvider.notifier).setOverlayTrack(t);
                      Navigator.pop(context);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Export GPX',
                          icon: const Icon(Icons.ios_share),
                          onPressed: () async {
                            final xml =
                                ref.read(gpxServiceProvider).exportTrack(t);
                            final file = await ref
                                .read(gpxServiceProvider)
                                .writeToDisk(t.name, xml);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Saved ${file.path}')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteWithUndo(t),
                        ),
                      ],
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
