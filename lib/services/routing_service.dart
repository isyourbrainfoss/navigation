import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../core/geometry.dart';
import '../core/maneuver.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import 'navigation_engine.dart';

class RouteRequest {
  const RouteRequest({
    required this.origin,
    required this.destination,
    required this.mode,
    this.vias = const [],
    this.alternatives = true,
    this.customBaseUrl = '',
  });

  final Place origin;
  final Place destination;
  final TravelMode mode;
  final List<Place> vias;
  final bool alternatives;
  final String customBaseUrl;
}

class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<RoutePlan>> route(RouteRequest request) async {
    final custom = request.customBaseUrl.trim();
    if (custom.contains('valhalla') || request.mode == TravelMode.truck) {
      return _valhalla(request);
    }
    if (custom.isNotEmpty) {
      return _osrm(request, baseOverride: custom);
    }
    return _osrm(request);
  }

  String _osrmBase(TravelMode mode) => switch (mode) {
        TravelMode.walk => AppConstants.osrmFootBase,
        TravelMode.bike => AppConstants.osrmBikeBase,
        TravelMode.drive || TravelMode.truck => AppConstants.osrmCarBase,
      };

  Future<List<RoutePlan>> _osrm(
    RouteRequest request, {
    String? baseOverride,
  }) async {
    final points = <Place>[
      request.origin,
      ...request.vias,
      request.destination,
    ];
    final coords = points
        .map((p) =>
            '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');
    var base = (baseOverride ?? _osrmBase(request.mode)).replaceAll(RegExp(r'/$'), '');
    // Allow pasting just the host; append standard path if needed.
    // FOSSGIS already includes /route/v1/driving (profile is in routed-foot etc).
    if (!base.contains('/route/')) {
      final profile = switch (request.mode) {
        TravelMode.walk => 'foot',
        TravelMode.bike => 'bike',
        TravelMode.drive || TravelMode.truck => 'driving',
      };
      base = '$base/route/v1/$profile';
    }
    final alt = request.alternatives ? 'true' : 'false';
    // Public OSRM rejects unknown annotation names such as maxspeed.
    final uri = Uri.parse(
      '$base/$coords?overview=full&geometries=polyline&steps=true'
      '&alternatives=$alt',
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

    final routes = body['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) throw RoutingException('No route found');

    final plans = <RoutePlan>[];
    for (var i = 0; i < routes.length; i++) {
      plans.add(
        _parseOsrmRoute(
          routes[i] as Map<String, dynamic>,
          request,
          i == 0 ? 'Best' : 'Alt ${i + 1}',
        ),
      );
    }
    return plans;
  }

  RoutePlan _parseOsrmRoute(
    Map<String, dynamic> route,
    RouteRequest request,
    String label,
  ) {
    final geometry = decodePolyline(route['geometry'] as String);
    final distance = (route['distance'] as num).toDouble();
    final duration = (route['duration'] as num).toDouble();

    final instructions = <NavInstruction>[];
    final legs = route['legs'] as List<dynamic>? ?? [];
    for (final leg in legs) {
      final steps =
          (leg as Map<String, dynamic>)['steps'] as List<dynamic>? ?? [];
      for (final step in steps) {
        final s = step as Map<String, dynamic>;
        final man = s['maneuver'] as Map<String, dynamic>? ?? {};
        final loc = man['location'] as List<dynamic>?;
        final lat =
            loc != null && loc.length >= 2 ? (loc[1] as num).toDouble() : 0.0;
        final lon =
            loc != null && loc.length >= 2 ? (loc[0] as num).toDouble() : 0.0;
        final type = man['type'] as String? ?? '';
        final modifier = man['modifier'] as String?;
        final name = s['name'] as String? ?? '';
        final exit = (man['exit'] as num?)?.toInt();
        final dist = (s['distance'] as num?)?.toDouble() ?? 0;
        final dur = (s['duration'] as num?)?.toDouble() ?? 0;
        instructions.add(
          NavInstruction(
            text: _instructionText(
              type: type,
              modifier: modifier,
              name: name,
              exit: exit,
            ),
            distanceMeters: dist,
            durationSeconds: dur,
            location: LatLng(lat, lon),
            modifier: modifier,
            type: type,
            name: name,
            lanes: _parseLanes(s),
            exit: exit,
          ),
        );
      }
    }

    final annotated = withAlongMeters(instructions, geometry);
    return RoutePlan(
      origin: request.origin,
      destination: request.destination,
      vias: request.vias,
      mode: request.mode,
      geometry: geometry,
      distanceMeters: distance,
      durationSeconds: duration,
      instructions: annotated,
      label: label,
      maxSpeedKph: _parseMaxspeed(route, geometry.length),
      summary: (route['legs'] as List?)
              ?.map((l) => (l as Map)['summary'])
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join(' · ') ??
          '',
    );
  }

  List<LaneInfo> _parseLanes(Map<String, dynamic> step) {
    final intersections = step['intersections'] as List<dynamic>? ?? [];
    if (intersections.isEmpty) return const [];
    final first = intersections.first as Map<String, dynamic>;
    final lanes = first['lanes'] as List<dynamic>?;
    if (lanes == null) return const [];
    return [
      for (final raw in lanes)
        if (raw is Map<String, dynamic>)
          LaneInfo(
            indications: ((raw['indications'] as List<dynamic>?) ?? [])
                .map((e) => e.toString())
                .toList(),
            valid: raw['valid'] == true,
          ),
    ];
  }

  List<double?> _parseMaxspeed(Map<String, dynamic> route, int geomLen) {
    final legs = route['legs'] as List<dynamic>? ?? [];
    final speeds = <double?>[];
    for (final leg in legs) {
      final ann = (leg as Map<String, dynamic>)['annotation'];
      if (ann is! Map<String, dynamic>) continue;
      final ms = ann['maxspeed'];
      if (ms is! List) continue;
      for (final v in ms) {
        if (v is num) {
          speeds.add(v.toDouble());
        } else if (v is String) {
          speeds.add(double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')));
        } else {
          speeds.add(null);
        }
      }
    }
    if (speeds.isEmpty) return const [];
    return speeds;
  }

  Future<List<RoutePlan>> _valhalla(RouteRequest request) async {
    var base = request.customBaseUrl.trim();
    if (base.isEmpty || !base.contains('valhalla')) {
      base = AppConstants.valhallaDefault;
    }
    base = base.replaceAll(RegExp(r'/$'), '');
    final costing = switch (request.mode) {
      TravelMode.walk => 'pedestrian',
      TravelMode.bike => 'bicycle',
      TravelMode.drive => 'auto',
      TravelMode.truck => 'truck',
    };
    final locations = <Map<String, dynamic>>[
      {'lat': request.origin.latitude, 'lon': request.origin.longitude},
      for (final v in request.vias)
        {'lat': v.latitude, 'lon': v.longitude, 'type': 'through'},
      {
        'lat': request.destination.latitude,
        'lon': request.destination.longitude,
      },
    ];
    final uri = Uri.parse('$base/route');
    final response = await _client.post(
      uri,
      headers: {
        'User-Agent': AppConstants.userAgent,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'locations': locations,
        'costing': costing,
        'directions_options': {'units': 'kilometers'},
      }),
    );
    if (response.statusCode != 200) {
      throw RoutingException('Routing failed (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final trip = body['trip'] as Map<String, dynamic>?;
    if (trip == null) throw RoutingException('No route found');
    final legs = trip['legs'] as List<dynamic>? ?? [];
    final geometry = <LatLng>[];
    final instructions = <NavInstruction>[];
    var distance = 0.0;
    var duration = 0.0;
    for (final leg in legs) {
      final l = leg as Map<String, dynamic>;
      final shapeOffset = geometry.length;
      final shape = l['shape'] as String? ?? '';
      if (shape.isNotEmpty) {
        geometry.addAll(decodePolyline(shape, precision: 6));
      }
      distance += ((l['summary'] as Map?)?['length'] as num?)?.toDouble() ?? 0;
      duration += ((l['summary'] as Map?)?['time'] as num?)?.toDouble() ?? 0;
      final mans = l['maneuvers'] as List<dynamic>? ?? [];
      for (final m in mans) {
        final man = m as Map<String, dynamic>;
        final begin =
            shapeOffset + (man['begin_shape_index'] as int? ?? 0);
        final loc = begin < geometry.length
            ? geometry[begin]
            : (geometry.isEmpty
                ? request.origin.latLng
                : geometry.last);
        instructions.add(
          NavInstruction(
            text: man['instruction'] as String? ?? 'Continue',
            distanceMeters:
                ((man['length'] as num?)?.toDouble() ?? 0) * 1000,
            durationSeconds: (man['time'] as num?)?.toDouble() ?? 0,
            location: loc,
            type: man['type']?.toString(),
            modifier: man['verbal_succinct_transition_instruction'] as String?,
            name: man['street_names'] is List
                ? (man['street_names'] as List).join(', ')
                : '',
          ),
        );
      }
    }
    // Valhalla length is km.
    final distanceM = distance * 1000;
    final annotated = withAlongMeters(instructions, geometry);
    return [
      RoutePlan(
        origin: request.origin,
        destination: request.destination,
        vias: request.vias,
        mode: request.mode,
        geometry: geometry,
        distanceMeters: distanceM,
        durationSeconds: duration,
        instructions: annotated,
        label: 'Best',
        summary: (trip['summary'] as Map?)?['max_lon'] != null ? '' : '',
      ),
    ];
  }

  String _instructionText({
    required String type,
    String? modifier,
    required String name,
    int? exit,
  }) {
    final road = name.isEmpty ? '' : ' onto $name';
    final mod = modifier == null || modifier.isEmpty
        ? ''
        : ' ${modifier.replaceAll('_', ' ')}';
    final exitPhrase = exit == null ? '' : ' ${Maneuver.ordinal(exit)}';

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
      'roundabout' || 'rotary' => exit == null
          ? 'Enter the roundabout$road'
          : 'Take the$exitPhrase exit$road',
      'exit roundabout' || 'exit rotary' => exit == null
          ? 'Exit the roundabout$road'
          : 'Take the$exitPhrase exit$road',
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
