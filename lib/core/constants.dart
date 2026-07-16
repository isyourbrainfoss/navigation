/// App-wide constants (identity, endpoints, defaults).
abstract final class AppConstants {
  static const appName = 'Navigation';
  static const packageId = 'com.isyourbrainfoss.navigation';
  static const userAgent =
      'Navigation/0.1 (https://github.com/isyourbrainfoss/navigation; FOSS)';

  /// Carto Voyager — free raster tiles, attribution required.
  static const tileUrlLight =
      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const tileUrlDark =
      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
  static const tileAttribution =
      '© OpenStreetMap contributors © CARTO';

  /// Photon geocoder (Komoot) — free, no key.
  static const photonBase = 'https://photon.komoot.io/api/';

  /// FOSSGIS public OSRM instances (foot / car).
  static const osrmFootBase =
      'https://routing.openstreetmap.de/routed-foot/route/v1/driving';
  static const osrmCarBase =
      'https://routing.openstreetmap.de/routed-car/route/v1/driving';

  static const defaultZoom = 14.0;
  static const navZoom = 17.0;
  static const minZoom = 3.0;
  static const maxZoom = 19.0;

  /// Offline region zoom range.
  static const offlineMinZoom = 8;
  static const offlineMaxZoom = 16;

  /// Re-route if farther than this from the route polyline (meters).
  static const offRouteMeters = 40.0;

  /// Arrived when within this distance of destination (meters).
  static const arrivalMeters = 25.0;

  static const searchDebounceMs = 280;
  static const searchLimit = 12;
  static const maxRecents = 20;
  static const maxFavorites = 50;

  /// Concurrent tile downloads (be polite to tile servers).
  static const tileDownloadConcurrency = 4;
  static const tileDownloadDelayMs = 40;
}
