import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/theme/navigation_theme.dart';
import 'features/map/map_screen.dart';
import 'models/app_settings.dart';
import 'providers/app_providers.dart';

class NavigationApp extends ConsumerWidget {
  const NavigationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final night = ref.watch(nightDrivingActiveProvider);
    final themeMode = night
        ? ThemeMode.dark
        : switch (settings.theme) {
            ThemePreference.light => ThemeMode.light,
            ThemePreference.dark => ThemeMode.dark,
            ThemePreference.system => ThemeMode.system,
          };

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: NavigationTheme.light(
        highContrast: settings.highContrast,
        largeHud: settings.largeHud,
      ),
      darkTheme: night
          ? NavigationTheme.nightDriving(
              highContrast: settings.highContrast,
              largeHud: settings.largeHud,
            )
          : NavigationTheme.dark(
              highContrast: settings.highContrast,
              largeHud: settings.largeHud,
            ),
      themeMode: themeMode,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped =
            mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.8);
        // Flutter GTK reports zero padding. Phosh still has a top panel
        // and a bottom gesture bar — fake insets on tall narrow windows.
        var pad = mq.padding;
        final phoneLike = mq.size.shortestSide < 560 ||
            (mq.size.width < 700 && mq.size.height > mq.size.width);
        if (phoneLike && pad.top < 24) {
          pad = pad.copyWith(
            top: pad.top + 46,
            bottom: pad.bottom < 16 ? pad.bottom + 40 : pad.bottom,
          );
        }
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped, padding: pad),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const MapScreen(),
    );
  }
}
