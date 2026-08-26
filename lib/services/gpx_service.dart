import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../core/geometry.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import '../models/track.dart';

class GpxDocument {
  const GpxDocument({
    this.name = 'Track',
    this.tracks = const [],
    this.routes = const [],
    this.waypoints = const [],
  });

  final String name;
  final List<SavedTrack> tracks;
  final List<List<LatLng>> routes;
  final List<Place> waypoints;

  List<LatLng> get primaryLine {
    if (tracks.isNotEmpty && tracks.first.points.isNotEmpty) {
      return tracks.first.latLngs;
    }
    if (routes.isNotEmpty) return routes.first;
    return waypoints.map((p) => p.latLng).toList();
  }
}

class GpxService {
  GpxDocument parse(String xml) {
    final doc = XmlDocument.parse(xml);
    final gpx = doc.rootElement;

    final waypoints = <Place>[];
    for (final wpt in gpx.findElements('wpt')) {
      final lat = double.tryParse(wpt.getAttribute('lat') ?? '');
      final lon = double.tryParse(wpt.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;
      final name = wpt.getElement('name')?.innerText ?? 'Waypoint';
      waypoints.add(
        Place(
          id: 'gpx_${lat}_$lon',
          name: name,
          latitude: lat,
          longitude: lon,
          subtitle: wpt.getElement('desc')?.innerText ?? 'GPX waypoint',
        ),
      );
    }

    final routes = <List<LatLng>>[];
    for (final rte in gpx.findElements('rte')) {
      final pts = <LatLng>[];
      for (final rp in rte.findElements('rtept')) {
        final lat = double.tryParse(rp.getAttribute('lat') ?? '');
        final lon = double.tryParse(rp.getAttribute('lon') ?? '');
        if (lat != null && lon != null) pts.add(LatLng(lat, lon));
      }
      if (pts.length >= 2) routes.add(pts);
    }

    final tracks = <SavedTrack>[];
    var i = 0;
    for (final trk in gpx.findElements('trk')) {
      final name = trk.getElement('name')?.innerText ?? 'Track';
      final points = <TrackPoint>[];
      for (final seg in trk.findElements('trkseg')) {
        for (final tp in seg.findElements('trkpt')) {
          final lat = double.tryParse(tp.getAttribute('lat') ?? '');
          final lon = double.tryParse(tp.getAttribute('lon') ?? '');
          if (lat == null || lon == null) continue;
          final ele = double.tryParse(tp.getElement('ele')?.innerText ?? '');
          final timeRaw = tp.getElement('time')?.innerText;
          final ts = timeRaw == null
              ? 0
              : (DateTime.tryParse(timeRaw)?.millisecondsSinceEpoch ?? 0);
          points.add(
            TrackPoint(
              latitude: lat,
              longitude: lon,
              timestampMs: ts,
              elevation: ele,
            ),
          );
        }
      }
      if (points.length < 2) continue;
      final dist = GeoMath.pathLengthMeters(points.map((p) => p.latLng).toList());
      tracks.add(
        SavedTrack(
          id: 'gpx_${DateTime.now().millisecondsSinceEpoch}_$i',
          name: name,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          points: points,
          distanceMeters: dist,
        ),
      );
      i++;
    }

    final title = gpx.getElement('metadata')?.getElement('name')?.innerText ??
        (tracks.isNotEmpty ? tracks.first.name : 'GPX');
    return GpxDocument(
      name: title,
      tracks: tracks,
      routes: routes,
      waypoints: waypoints,
    );
  }

  String exportTrack(SavedTrack track) {
    return _build(
      name: track.name,
      points: track.points,
      isTrack: true,
    );
  }

  String exportRoute(RoutePlan plan) {
    final pts = [
      for (final p in plan.geometry)
        TrackPoint(
          latitude: p.latitude,
          longitude: p.longitude,
          timestampMs: 0,
        ),
    ];
    return _build(
      name: 'Route to ${plan.destination.name}',
      points: pts,
      isTrack: false,
    );
  }

  String _build({
    required String name,
    required List<TrackPoint> points,
    required bool isTrack,
  }) {
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="Navigation" '
        'xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..writeln('  <metadata><name>${_esc(name)}</name></metadata>');
    if (isTrack) {
      b.writeln('  <trk><name>${_esc(name)}</name><trkseg>');
      for (final p in points) {
        b.write('    <trkpt lat="${p.latitude}" lon="${p.longitude}">');
        if (p.elevation != null) {
          b.write('<ele>${p.elevation}</ele>');
        }
        if (p.timestampMs > 0) {
          b.write(
            '<time>${DateTime.fromMillisecondsSinceEpoch(p.timestampMs, isUtc: true).toIso8601String()}</time>',
          );
        }
        b.writeln('</trkpt>');
      }
      b.writeln('  </trkseg></trk>');
    } else {
      b.writeln('  <rte><name>${_esc(name)}</name>');
      for (final p in points) {
        b.writeln(
          '    <rtept lat="${p.latitude}" lon="${p.longitude}"></rtept>',
        );
      }
      b.writeln('  </rte>');
    }
    b.writeln('</gpx>');
    return b.toString();
  }

  Future<File> writeToDisk(String name, String xml) async {
    Directory dir;
    try {
      dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = await getApplicationDocumentsDirectory();
    }
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final file = File(p.join(dir.path, '$safe.gpx'));
    await file.writeAsString(xml);
    return file;
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
