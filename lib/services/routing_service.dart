import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../core/geometry.dart';
import '../models/place.dart';
import '../models/route_plan.dart';

class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<RoutePlan> route({
    required Place origin,
    required Place destination,
    required TravelMode mode,
  }) async {
    final base = switch (mode) {
      TravelMode.walk => AppConstants.osrmFootBase,
      TravelMode.drive => AppConstants.osrmCarBase,
    };
    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.parse(
      '$base/$coords?overview=full&geometries=polyline&steps=true&annotations=false',
    );

    final response = await _client.get(
      uri,
      headers: {'User-Agent': AppConstants.userAgent},
    );
    if (response.statusCode != 200) {
      throw RoutingException('Routing failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final code = body['code'] as String? ?? '';
    if (code != 'Ok') {
      throw RoutingException(body['message'] as String? ?? 'No route found');
    }

    final routes = body['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw RoutingException('No route found');
    }
    final route = routes.first as Map<String, dynamic>;
    final geometry = decodePolyline(route['geometry'] as String);
    final distance = (route['distance'] as num).toDouble();
    final duration = (route['duration'] as num).toDouble();

    final instructions = <NavInstruction>[];
    final legs = route['legs'] as List<dynamic>? ?? [];
    for (final leg in legs) {
      final steps = (leg as Map<String, dynamic>)['steps'] as List<dynamic>? ?? [];
      for (final step in steps) {
        final s = step as Map<String, dynamic>;
        final man = s['maneuver'] as Map<String, dynamic>? ?? {};
        final loc = man['location'] as List<dynamic>?;
        final lat = loc != null && loc.length >= 2
            ? (loc[1] as num).toDouble()
            : 0.0;
        final lon = loc != null && loc.length >= 2
            ? (loc[0] as num).toDouble()
            : 0.0;
        final type = man['type'] as String? ?? '';
        final modifier = man['modifier'] as String?;
        final name = s['name'] as String? ?? '';
        final dist = (s['distance'] as num?)?.toDouble() ?? 0;
        final dur = (s['duration'] as num?)?.toDouble() ?? 0;
        instructions.add(
          NavInstruction(
            text: _instructionText(type: type, modifier: modifier, name: name),
            distanceMeters: dist,
            durationSeconds: dur,
            location: LatLng(lat, lon),
            modifier: modifier,
            type: type,
            name: name,
          ),
        );
      }
    }

    return RoutePlan(
      origin: origin,
      destination: destination,
      mode: mode,
      geometry: geometry,
      distanceMeters: distance,
      durationSeconds: duration,
      instructions: instructions,
    );
  }

  String _instructionText({
    required String type,
    String? modifier,
    required String name,
  }) {
    final road = name.isEmpty ? '' : ' onto $name';
    final mod = modifier == null || modifier.isEmpty
        ? ''
        : ' ${modifier.replaceAll('_', ' ')}';

    return switch (type) {
      'depart' => name.isEmpty ? 'Head out' : 'Head out on $name',
      'arrive' => 'You have arrived',
      'turn' => 'Turn$mod$road',
      'new name' => name.isEmpty ? 'Continue' : 'Continue on $name',
      'merge' => 'Merge$mod$road',
      'on ramp' => 'Take the ramp$mod$road',
      'off ramp' => 'Take the exit$mod$road',
      'fork' => 'Keep$mod$road',
      'end of road' => 'At the end of the road, turn$mod$road',
      'continue' => name.isEmpty ? 'Continue' : 'Continue on $name',
      'roundabout' || 'rotary' => 'Enter the roundabout$road',
      'exit roundabout' || 'exit rotary' => 'Exit the roundabout$road',
      'notification' => name.isEmpty ? 'Continue' : name,
      _ => type.isEmpty
          ? (name.isEmpty ? 'Continue' : 'Continue on $name')
          : '${type.replaceAll('_', ' ')}$mod$road',
    };
  }

  void dispose() {
    _client.close();
  }
}

class RoutingException implements Exception {
  RoutingException(this.message);
  final String message;
  @override
  String toString() => message;
}
