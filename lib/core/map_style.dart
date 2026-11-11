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
///
/// Allowlist: only keyed CARTO basemaps. OpenStreetMap's tile usage policy
/// forbids bulk downloads, and the volunteer-run OpenTopoMap and CyclOSM
/// servers ask apps not to scrape them either. Keyless CARTO only serves
/// "API KEY REQUIRED" placeholders, so it is not downloadable.
bool tileSourceAllowsBulkDownload(String urlTemplate) {
  final uri = Uri.tryParse(urlTemplate.replaceAll(RegExp(r'[{}]'), ''));
  if (uri == null || uri.scheme != 'https') return false;
  final host = uri.host;
  final isCarto = host == 'basemaps.cartocdn.com' ||
      host.endsWith('.basemaps.cartocdn.com');
  return isCarto && (uri.queryParameters['key'] ?? '').trim().isNotEmpty;
}

/// Cache directory keys for keyed CARTO styles. Deliberately *not* the old
/// `light` / `dark` keys, which may hold cached keyless "API KEY REQUIRED"
/// placeholder tiles (those dirs are purged once by [TileCacheService]).
const cartoLightStyleKey = 'carto-light';
const cartoDarkStyleKey = 'carto-dark';

/// Legacy cache keys used for CARTO before it needed an API key.
const legacyCartoStyleKeys = ['light', 'dark'];

/// Every style key that may own tiles in the offline cache.
const allTileStyleKeys = [
  cartoLightStyleKey,
  cartoDarkStyleKey,
  'osm',
  'topo',
  'cycle',
  ...legacyCartoStyleKeys,
];

/// Replace any CARTO `key=` value in [text] (URLs, exception messages) so
/// API keys never end up in logs.
String redactTileKey(String text) => text.replaceAllMapped(
  RegExp(r'''([?&]key=)[^&\s#'"]*'''),
  (m) => '${m[1]}<redacted>',
);

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
      styleKey: dark ? cartoDarkStyleKey : cartoLightStyleKey,
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
