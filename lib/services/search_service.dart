import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../models/place.dart';

/// Photon (Komoot) geocoder + light local re-ranking.
class SearchService {
  SearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Place>> search(
    String query, {
    LatLng? bias,
    int limit = AppConstants.searchLimit,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final params = <String, String>{
      'q': q,
      'limit': '$limit',
      'lang': 'en',
    };
    if (bias != null) {
      params['lat'] = bias.latitude.toStringAsFixed(5);
      params['lon'] = bias.longitude.toStringAsFixed(5);
    }

    final uri = Uri.parse(AppConstants.photonBase).replace(queryParameters: params);
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
    return _rank(places, q);
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

  /// Prefer exact / prefix matches; keep Photon order as secondary key.
  List<Place> _rank(List<Place> places, String query) {
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
      // Token match
      for (final token in q.split(RegExp(r'\s+'))) {
        if (token.isEmpty) continue;
        if (name.contains(token)) score += 10;
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
