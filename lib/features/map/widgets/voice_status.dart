import 'package:flutter/material.dart';

class VoiceStatusBanner extends StatelessWidget {
  const VoiceStatusBanner({super.key, this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final text = reason;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
