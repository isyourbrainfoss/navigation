import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/camera_view.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _key = 'navigation_settings_v1';
  static const cameraKey = 'navigation_camera_v1';
  static const locationIntroKey = 'navigation_location_intro_v1';

  final SharedPreferences _prefs;

  static Future<SettingsRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsRepository(prefs);
  }

  AppSettings load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return AppSettings.defaults;
    try {
      return AppSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return AppSettings.defaults;
    }
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  CameraView? loadCamera() {
    final raw = _prefs.getString(cameraKey);
    if (raw == null) return null;
    try {
      return CameraView.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCamera(CameraView view) async {
    await _prefs.setString(cameraKey, jsonEncode(view.toJson()));
  }

  bool loadLocationIntroSeen() => _prefs.getBool(locationIntroKey) ?? false;

  Future<void> setLocationIntroSeen() async {
    await _prefs.setBool(locationIntroKey, true);
  }
}
