import 'package:flutter/material.dart';

/// Shown when several map tile fetches in a row have failed.
///
/// The app does not know *why* tiles failed (offline, tile server busy or
/// rate-limiting, a zoom level the server does not serve, ...), so the copy
/// must not claim there is no internet connection.
class TilesFailingBanner extends StatelessWidget {
  const TilesFailingBanner({super.key});

  static const message =
      'Map tiles couldn\'t be loaded. Places you have already viewed still '
      'show. If you\'re online, the tile server may be busy — try again '
      'shortly.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.map_outlined,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
