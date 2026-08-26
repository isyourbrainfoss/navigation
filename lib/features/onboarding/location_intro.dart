import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// First-run why-GPS panel. Returns `true` if Enable location was tapped.
Future<bool> showLocationIntro(BuildContext context) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => LocationIntroPage(
        onEnable: () => Navigator.pop(ctx, true),
        onDismiss: () => Navigator.pop(ctx, false),
      ),
    ),
  );
  return result ?? false;
}

/// Full-screen first-launch explanation (GeoClue copy on Linux).
class LocationIntroPage extends StatelessWidget {
  const LocationIntroPage({
    super.key,
    required this.onEnable,
    required this.onDismiss,
  });

  final VoidCallback onEnable;
  final VoidCallback onDismiss;

  static const _title = 'Turn-by-turn needs your location';

  static const _bodyLinux =
      'Guidance, the blue dot, and recorded tracks use GPS through GeoClue. '
      'Enable Location in system settings (Privacy → Location) if you are not '
      'prompted, then tap Enable location.';

  static const _bodyDefault =
      'Guidance, the blue dot, and recorded tracks use GPS. Allow location '
      'when prompted, or enable Location in system settings.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final linux = theme.platform == TargetPlatform.linux;
    const buttonStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size.fromHeight(AppConstants.minTouchDp),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 112,
                    height: 112,
                    child: Icon(
                      Icons.my_location,
                      size: 48,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                linux ? _bodyLinux : _bodyDefault,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onEnable,
                style: buttonStyle,
                child: const Text('Enable location'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onDismiss,
                style: buttonStyle,
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
