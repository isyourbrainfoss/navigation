import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../models/place.dart';

/// Compact long-press place card.
///
/// Returns `'go'`, `'via'`, `'save'`, or `null` if dismissed / cancelled.
Future<String?> showPlacePeek(
  BuildContext context, {
  required Place place,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => PlacePeek(place: place),
  );
}

class PlacePeek extends StatelessWidget {
  const PlacePeek({super.key, required this.place});

  final Place place;

  static const Size _touch = Size(64, AppConstants.minTouchDp);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = place.subtitle.isEmpty
        ? '${place.latitude.toStringAsFixed(5)}, '
            '${place.longitude.toStringAsFixed(5)}'
        : place.subtitle;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(72, AppConstants.minTouchDp),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: AppConstants.minTouchDp,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, 'go'),
                      style: FilledButton.styleFrom(
                        minimumSize: _touch,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.navigation, size: 20),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Navigate'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: AppConstants.minTouchDp,
                    height: AppConstants.minTouchDp,
                    child: IconButton.outlined(
                      tooltip: 'Save',
                      onPressed: () => Navigator.pop(context, 'save'),
                      icon: const Icon(Icons.star_outline),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 'via'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: _touch,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(
                        Icons.add_location_alt_outlined,
                        size: 20,
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Add stop'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
