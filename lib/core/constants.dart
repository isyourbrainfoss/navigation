/// App-wide constants (identity, endpoints, defaults).
abstract final class AppConstants {
  static const appName = 'Navigation';
  static const packageId = 'com.isyourbrainfoss.Navigation';
  static const userAgent =
      'Navigation/0.2 (https://github.com/isyourbrainfoss/navigation; FOSS)';

  /// OpenStreetMap standard tiles — keyless default. Their tile usage
  /// policy forbids bulk downloads, so offline regions need another source.
  static const tileUrlOsm = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const tileAttributionOsm = '© OpenStreetMap contributors';

  /// CARTO Voyager / Dark Matter. Since 25 Sep 2026 these need a (free)
  /// API key from https://carto.com/basemaps/apikey/ — keyless requests
  /// only return "API KEY REQUIRED" tiles.
  static const tileUrlLight =
      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const tileUrlDark =
      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
  static const tileUrlTopo =
      'https://a.tile.opentopomap.org/{z}/{x}/{y}.png';
  static const tileUrlCycle =
      'https://a.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png';
  static const tileAttributionCarto =
      '© OpenStreetMap contributors © CARTO';
  static const tileAttributionTopo =
      '© OpenStreetMap contributors © OpenTopoMap (CC-BY-SA)';
  static const tileAttributionCycle =
      '© OpenStreetMap contributors © CyclOSM';

  /// Photon geocoder (Komoot) — free, no key.
  static const photonBase = 'https://photon.komoot.io/api/';
  static const photonReverse = 'https://photon.komoot.io/reverse';

  static const overpassUrl = 'https://overpass-api.de/api/interpreter';

  /// FOSSGIS public OSRM instances.
  static const osrmFootBase =
      'https://routing.openstreetmap.de/routed-foot/route/v1/driving';
  static const osrmBikeBase =
      'https://routing.openstreetmap.de/routed-bike/route/v1/driving';
  static const osrmCarBase =
      'https://routing.openstreetmap.de/routed-car/route/v1/driving';

  /// Public Valhalla (truck + optional custom).
  static const valhallaDefault = 'https://valhalla1.openstreetmap.de';

  static const defaultZoom = 14.0;
  static const navZoom = 17.0;
  static const walkZoom = 18.0;
  static const highwayZoom = 15.0;
  static const minZoom = 3.0;
  static const maxZoom = 19.0;

  static const offlineMinZoom = 8;
  static const offlineMaxZoom = 16;

  /// Off-route: enter at [offRouteEnterMeters], stay until closer than [offRouteExitMeters].
  static const offRouteEnterMeters = 50.0;
  static const offRouteExitMeters = 22.0;
  static const offRouteConsecutiveFixes = 3;
  static const rerouteCooldown = Duration(seconds: 12);

  /// Snap the puck onto the route when closer than this.
  static const snapDisplayMeters = 80.0;

  static const arrivalMeters = 25.0;
  static const approachingMeters = 80.0;

  static const voiceFarMeters = 400.0;
  static const voiceNearMeters = 200.0;
  static const voiceNowMeters = 80.0;

  static const searchDebounceMs = 280;
  static const searchLimit = 12;
  static const maxRecents = 20;
  static const maxFavorites = 80;
  static const maxBookmarkFolders = 24;

  static const tileDownloadConcurrency = 4;
  static const tileDownloadDelayMs = 40;

  static const minTouchDp = 56.0;
}
