import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/geometry.dart';
import '../models/track.dart';
import 'location_service.dart';

class TrackRepository {
  TrackRepository(this._prefs);

  static const _key = 'navigation_tracks_v1';
  final SharedPreferences _prefs;

  static Future<TrackRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return TrackRepository(prefs);
  }

  List<SavedTrack> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedTrack.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<SavedTrack> tracks) async {
    await _prefs.setString(
      _key,
      jsonEncode(tracks.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> add(SavedTrack track) async {
    final list = load()..insert(0, track);
    while (list.length > 40) {
      list.removeLast();
    }
    await saveAll(list);
  }

  Future<void> delete(String id) async {
    final list = load()..removeWhere((t) => t.id == id);
    await saveAll(list);
  }
}

class TrackRecorder {
  final _points = <TrackPoint>[];
  bool recording = false;
  DateTime? startedAt;

  List<TrackPoint> get points => List.unmodifiable(_points);

  double get distanceMeters =>
      GeoMath.pathLengthMeters(_points.map((p) => p.latLng).toList());

  void start() {
    _points.clear();
    recording = true;
    startedAt = DateTime.now();
  }

  void addFix(LocationFix fix) {
    if (!recording) return;
    final last = _points.isEmpty ? null : _points.last;
    if (last != null) {
      final d = GeoMath.haversineMeters(last.latLng, fix.position);
      if (d < 4) return;
    }
    _points.add(
      TrackPoint(
        latitude: fix.position.latitude,
        longitude: fix.position.longitude,
        timestampMs: fix.timestamp.millisecondsSinceEpoch,
        elevation: fix.altitudeMeters,
        speedMps: fix.speedMps,
      ),
    );
  }

  SavedTrack? stop() {
    recording = false;
    if (_points.length < 2) return null;
    return SavedTrack(
      id: 'trk_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Track ${DateTime.now().toIso8601String().substring(0, 16)}',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      points: List.of(_points),
      distanceMeters: distanceMeters,
    );
  }
}
