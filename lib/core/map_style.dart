import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import 'constants.dart';

class ResolvedMapStyle {
  const ResolvedMapStyle({
    required this.urlTemplate,
    required this.attribution,
    required this.styleKey,
    required this.dark,
  });

  final String urlTemplate;
  final String attribution;
  final String styleKey;
  final bool dark;
}

ResolvedMapStyle resolveMapStyle({
  required AppSettings settings,
  required Brightness platform,
  required bool nightDriving,
}) {
  if (nightDriving) {
    return const ResolvedMapStyle(
      urlTemplate: AppConstants.tileUrlDark,
      attribution: AppConstants.tileAttributionCarto,
      styleKey: 'dark',
      dark: true,
    );
  }
  switch (settings.mapStyle) {
    case MapStylePreference.light:
      return const ResolvedMapStyle(
        urlTemplate: AppConstants.tileUrlLight,
        attribution: AppConstants.tileAttributionCarto,
        styleKey: 'light',
        dark: false,
      );
    case MapStylePreference.dark:
      return const ResolvedMapStyle(
        urlTemplate: AppConstants.tileUrlDark,
        attribution: AppConstants.tileAttributionCarto,
        styleKey: 'dark',
        dark: true,
      );
    case MapStylePreference.topo:
      return const ResolvedMapStyle(
        urlTemplate: AppConstants.tileUrlTopo,
        attribution: AppConstants.tileAttributionTopo,
        styleKey: 'topo',
        dark: false,
      );
    case MapStylePreference.cycle:
      return const ResolvedMapStyle(
        urlTemplate: AppConstants.tileUrlCycle,
        attribution: AppConstants.tileAttributionCycle,
        styleKey: 'cycle',
        dark: false,
      );
    case MapStylePreference.auto:
      final dark = platform == Brightness.dark;
      return ResolvedMapStyle(
        urlTemplate:
            dark ? AppConstants.tileUrlDark : AppConstants.tileUrlLight,
        attribution: AppConstants.tileAttributionCarto,
        styleKey: dark ? 'dark' : 'light',
        dark: dark,
      );
  }
}
