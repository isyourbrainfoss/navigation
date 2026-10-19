import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import 'constants.dart';

class ResolvedMapStyle {
  const ResolvedMapStyle({
    required this.urlTemplate,
    required this.attribution,
    required this.styleKey,
    required this.dark,
    this.invertTiles = false,
  });

  final String urlTemplate;
  final String attribution;
  final String styleKey;
  final bool dark;

  /// Light tiles shown through an inverting colour filter (keyless dark map).
  final bool invertTiles;
}

/// Whether [urlTemplate]'s tile server allows bulk (offline region) downloads.
bool tileSourceAllowsBulkDownload(String urlTemplate) =>
    !urlTemplate.contains('tile.openstreetmap.org');

String _withCartoKey(String url, String key) =>
    '$url?key=${Uri.encodeQueryComponent(key)}';

ResolvedMapStyle _street({required bool dark, required String cartoKey}) {
  final key = cartoKey.trim();
  if (key.isNotEmpty) {
    return ResolvedMapStyle(
      urlTemplate: _withCartoKey(
        dark ? AppConstants.tileUrlDark : AppConstants.tileUrlLight,
        key,
      ),
      attribution: AppConstants.tileAttributionCarto,
      styleKey: dark ? 'dark' : 'light',
      dark: dark,
    );
  }
  return ResolvedMapStyle(
    urlTemplate: AppConstants.tileUrlOsm,
    attribution: AppConstants.tileAttributionOsm,
    styleKey: 'osm',
    dark: dark,
    invertTiles: dark,
  );
}

ResolvedMapStyle resolveMapStyle({
  required AppSettings settings,
  required Brightness platform,
  required bool nightDriving,
}) {
  final cartoKey = settings.cartoApiKey;
  if (nightDriving) {
    return _street(dark: true, cartoKey: cartoKey);
  }
  switch (settings.mapStyle) {
    case MapStylePreference.light:
      return _street(dark: false, cartoKey: cartoKey);
    case MapStylePreference.dark:
      return _street(dark: true, cartoKey: cartoKey);
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
      return _street(dark: platform == Brightness.dark, cartoKey: cartoKey);
  }
}
