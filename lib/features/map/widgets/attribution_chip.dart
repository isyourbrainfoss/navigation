import 'package:flutter/material.dart';

/// Collapsed map credit. Tap reveals the full attribution string.
class AttributionChip extends StatelessWidget {
  const AttributionChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: text,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => _reveal(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              '©',
              semanticsLabel: text,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                height: 1,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _reveal(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(text),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.paddingOf(ctx).bottom + 16,
          child: Material(
            elevation: 8,
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(text, style: Theme.of(ctx).textTheme.bodyMedium),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }
}
