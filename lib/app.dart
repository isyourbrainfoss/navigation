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
    final themeMode = switch (settings.theme) {
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
      ThemePreference.system => ThemeMode.system,
    };

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: NavigationTheme.light(),
      darkTheme: NavigationTheme.dark(),
      themeMode: themeMode,
      home: const MapScreen(),
    );
  }
}
