import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../core/geometry.dart';
import '../models/place.dart';
import '../models/route_plan.dart';

class PoiCategory {
  const PoiCategory({
    required this.id,
    required this.label,
    required this.osmTag,
    required this.query,
  });

  final String id;
  final String label;
  final String osmTag;
  final String query;

  static const all = <PoiCategory>[
    PoiCategory(
      id: 'fuel',
      label: 'Fuel',
      osmTag: 'amenity:fuel',
      query: 'fuel',
    ),
    PoiCategory(
      id: 'parking',
      label: 'Parking',
      osmTag: 'amenity:parking',
      query: 'parking',
    ),
    PoiCategory(
      id: 'food',
      label: 'Food',
      osmTag: 'amenity:restaurant',
      query: 'restaurant',
    ),
    PoiCategory(
      id: 'cafe',
      label: 'Cafe',
      osmTag: 'amenity:cafe',
      query: 'cafe',
    ),
    PoiCategory(
      id: 'shop',
      label: 'Shop',
      osmTag: 'shop:supermarket',
      query: 'supermarket',
    ),
    PoiCategory(
      id: 'pharmacy',
      label: 'Pharmacy',
      osmTag: 'amenity:pharmacy',
      query: 'pharmacy',
    ),
    PoiCategory(
      id: 'hospital',
      label: 'Hospital',
      osmTag: 'amenity:hospital',
      query: 'hospital',
    ),
    PoiCategory(
      id: 'atm',
      label: 'ATM',
      osmTag: 'amenity:atm',
      query: 'atm',
    ),
  ];
}

/// Photon (Komoot) geocoder + coordinate parsing + Overpass nearby.
class SearchService {
  SearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final _coordRe = RegExp(
    r'^\s*(-?\d{1,3}(?:\.\d+)?)\s*[, ]\s*(-?\d{1,3}(?:\.\d+)?)\s*$',
  );
  static final _geoRe = RegExp(
    r'geo:(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  Place? parseCoordinates(String raw) {
    final geo = _geoRe.firstMatch(raw.trim());
    if (geo != null) {
      final lat = double.tryParse(geo.group(1)!);
      final lon = double.tryParse(geo.group(2)!);
      if (lat != null && lon != null && lat.abs() <= 90 && lon.abs() <= 180) {
        return Place(
          id: 'coord_${lat}_$lon',
          name: '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
          latitude: lat,
          longitude: lon,
          subtitle: 'Coordinates',
        );
      }
    }
    final m = _coordRe.firstMatch(raw.trim());
    if (m == null) return null;
    final a = double.tryParse(m.group(1)!);
    final b = double.tryParse(m.group(2)!);
    if (a == null || b == null) return null;
    // Heuristic: if |a|<=90 treat as lat,lon; if |b|<=90 and |a|>90, lon,lat.
    double lat;
    double lon;
    if (a.abs() <= 90 && b.abs() <= 180) {
      lat = a;
      lon = b;
    } else {
      return null;
    }
    return Place(
      id: 'coord_${lat}_$lon',
      name: '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
      latitude: lat,
      longitude: lon,
      subtitle: 'Coordinates',
    );
  }

  Future<List<Place>> search(
    String query, {
    LatLng? bias,
    int limit = AppConstants.searchLimit,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final coord = parseCoordinates(q);
    if (coord != null) return [coord];

    final params = <String, String>{
      'q': q,
      'limit': '$limit',
      'lang': 'en',
    };
    if (bias != null) {
      params['lat'] = bias.latitude.toStringAsFixed(5);
      params['lon'] = bias.longitude.toStringAsFixed(5);
    }

    final uri =
        Uri.parse(AppConstants.photonBase).replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'User-Agent': AppConstants.userAgent},
    );
    if (response.statusCode != 200) {
      throw SearchException('Search failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = body['features'] as List<dynamic>? ?? [];
    final places = features.map(_featureToPlace).whereType<Place>().toList();
    return _rank(places, q, bias: bias);
  }

  Future<List<Place>> searchCategory(
    PoiCategory category, {
    required LatLng bias,
    int limit = 12,
  }) async {
    final params = <String, String>{
      'q': category.query,
      'lat': bias.latitude.toStringAsFixed(5),
      'lon': bias.longitude.toStringAsFixed(5),
      'limit': '$limit',
      'osm_tag': category.osmTag,
    };
    final uri =
        Uri.parse(AppConstants.photonBase).replace(queryParameters: params);
    try {
      final response = await _client.get(
        uri,
        headers: {'User-Agent': AppConstants.userAgent},
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final features = body['features'] as List<dynamic>? ?? [];
        final places =
            features.map(_featureToPlace).whereType<Place>().toList();
        if (places.isNotEmpty) return _rank(places, category.query, bias: bias);
      }
    } catch (_) {}
    return nearbyOverpass(
      lat: bias.latitude,
      lon: bias.longitude,
      osmTag: category.osmTag,
    );
  }

  Future<Place?> reverse(LatLng ll) async {
    final uri = Uri.parse(AppConstants.photonReverse).replace(
      queryParameters: {
        'lat': ll.latitude.toStringAsFixed(6),
        'lon': ll.longitude.toStringAsFixed(6),
      },
    );
    try {
      final response = await _client.get(
        uri,
        headers: {'User-Agent': AppConstants.userAgent},
      );
      if (response.statusCode != 200) return Place.fromLatLng(ll);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final features = body['features'] as List<dynamic>? ?? [];
      if (features.isEmpty) return Place.fromLatLng(ll);
      return _featureToPlace(features.first) ?? Place.fromLatLng(ll);
    } catch (_) {
      return Place.fromLatLng(ll);
    }
  }

  Future<List<Place>> nearbyOverpass({
    required double lat,
    required double lon,
    required String osmTag,
    double radiusMeters = 1200,
  }) async {
    final parts = osmTag.split(':');
    if (parts.length != 2) return const [];
    final key = parts[0];
    final value = parts[1];
    final query = '[out:json][timeout:8];'
        'nwr(around:${radiusMeters.round()},$lat,$lon)[$key=$value];'
        'out center 24;';
    try {
      final response = await _client.post(
        Uri.parse(AppConstants.overpassUrl),
        headers: {
          'User-Agent': AppConstants.userAgent,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'data=${Uri.encodeQueryComponent(query)}',
      );
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = body['elements'] as List<dynamic>? ?? [];
      final places = <Place>[];
      for (final e in elements) {
        if (e is! Map<String, dynamic>) continue;
        final tags = e['tags'] as Map<String, dynamic>? ?? {};
        final name = tags['name'] as String?;
        if (name == null || name.isEmpty) continue;
        double? elat = (e['lat'] as num?)?.toDouble();
        double? elon = (e['lon'] as num?)?.toDouble();
        final center = e['center'] as Map<String, dynamic>?;
        elat ??= (center?['lat'] as num?)?.toDouble();
        elon ??= (center?['lon'] as num?)?.toDouble();
        if (elat == null || elon == null) continue;
        places.add(
          Place(
            id: 'osm_${e['type']}_${e['id']}',
            name: name,
            latitude: elat,
            longitude: elon,
            subtitle: tags['addr:street'] as String? ?? value,
            osmKey: key,
            osmValue: value,
          ),
        );
      }
      places.sort((a, b) {
        final da = GeoMath.haversineMeters(LatLng(lat, lon), a.latLng);
        final db = GeoMath.haversineMeters(LatLng(lat, lon), b.latLng);
        return da.compareTo(db);
      });
      return places.take(16).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Place>> searchAlongRoute(
    String query, {
    required RoutePlan route,
    int limit = 10,
  }) async {
    if (route.geometry.length < 2) {
      return search(query, bias: route.destination.latLng);
    }
    // Sample a few points along the remaining geometry.
    final samples = <LatLng>[];
    final step = (route.geometry.length / 4).ceil().clamp(1, route.geometry.length);
    for (var i = 0; i < route.geometry.length; i += step) {
      samples.add(route.geometry[i]);
    }
    samples.add(route.destination.latLng);
    final seen = <String>{};
    final out = <Place>[];
    for (final s in samples.take(4)) {
      final found = await search(query, bias: s, limit: 6);
      for (final p in found) {
        if (seen.add(p.id)) out.add(p);
      }
    }
    out.sort((a, b) {
      final da = GeoMath.distanceToPolylineMeters(a.latLng, route.geometry);
      final db = GeoMath.distanceToPolylineMeters(b.latLng, route.geometry);
      return da.compareTo(db);
    });
    return out.take(limit).toList();
  }

  Place? _featureToPlace(dynamic feature) {
    if (feature is! Map<String, dynamic>) return null;
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final props = feature['properties'] as Map<String, dynamic>?;
    if (geometry == null || props == null) return null;
    final coords = geometry['coordinates'] as List<dynamic>?;
    if (coords == null || coords.length < 2) return null;

    final lon = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();
    final name = (props['name'] as String?)?.trim();
    final street = props['street'] as String?;
    final housenumber = props['housenumber'] as String?;
    final city = props['city'] as String? ??
        props['town'] as String? ??
        props['village'] as String? ??
        props['county'] as String?;
    final state = props['state'] as String?;
    final country = props['country'] as String?;
    final osmType = props['osm_type']?.toString() ?? '';
    final osmId = props['osm_id']?.toString() ?? '';
    final osmKey = props['osm_key'] as String?;
    final osmValue = props['osm_value'] as String?;

    final title = name ??
        [
          ?housenumber,
          ?street,
        ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    if (title.isEmpty) return null;

    final addressLine = name != null && street != null
        ? [
            ?housenumber,
            street,
          ].whereType<String>().where((s) => s.isNotEmpty).join(' ')
        : null;
    final subtitleParts = <String>[
      ?addressLine,
      ?city,
      if (state != null && state != city) state,
      ?country,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();

    return Place(
      id: 'osm_${osmType}_$osmId',
      name: title,
      latitude: lat,
      longitude: lon,
      subtitle: subtitleParts.join(', '),
      osmKey: osmKey,
      osmValue: osmValue,
    );
  }

  List<Place> _rank(List<Place> places, String query, {LatLng? bias}) {
    final q = query.toLowerCase();
    final scored = <({Place place, int score, int index})>[];
    for (var i = 0; i < places.length; i++) {
      final p = places[i];
      final name = p.name.toLowerCase();
      final sub = p.subtitle.toLowerCase();
      var score = 0;
      if (name == q) {
        score += 100;
      } else if (name.startsWith(q)) {
        score += 80;
      } else if (name.contains(q)) {
        score += 50;
      } else if (sub.contains(q)) {
        score += 30;
      }
      for (final token in q.split(RegExp(r'\s+'))) {
        if (token.isEmpty) continue;
        if (name.contains(token)) score += 10;
      }
      if (bias != null) {
        final d = GeoMath.haversineMeters(bias, p.latLng);
        if (d < 500) score += 25;
        if (d < 2000) score += 10;
      }
      scored.add((place: p, score: score, index: i));
    }
    scored.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return a.index.compareTo(b.index);
    });
    return scored.map((e) => e.place).toList();
  }

  void dispose() {
    _client.close();
  }
}

class SearchException implements Exception {
  SearchException(this.message);
  final String message;
  @override
  String toString() => message;
}
