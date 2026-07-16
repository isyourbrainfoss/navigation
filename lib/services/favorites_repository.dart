import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/place.dart';

class FavoritesRepository {
  FavoritesRepository(this._prefs);

  static const _favoritesKey = 'navigation_favorites_v1';
  static const _recentsKey = 'navigation_recents_v1';

  final SharedPreferences _prefs;

  static Future<FavoritesRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return FavoritesRepository(prefs);
  }

  List<Place> loadFavorites() => _loadList(_favoritesKey);

  List<Place> loadRecents() => _loadList(_recentsKey);

  Future<void> addFavorite(Place place) async {
    final list = loadFavorites();
    list.removeWhere((p) => p.id == place.id);
    list.insert(0, place);
    while (list.length > AppConstants.maxFavorites) {
      list.removeLast();
    }
    await _saveList(_favoritesKey, list);
  }

  Future<void> removeFavorite(String id) async {
    final list = loadFavorites()..removeWhere((p) => p.id == id);
    await _saveList(_favoritesKey, list);
  }

  bool isFavorite(String id) => loadFavorites().any((p) => p.id == id);

  Future<void> addRecent(Place place) async {
    final list = loadRecents();
    list.removeWhere((p) => p.id == place.id);
    list.insert(0, place);
    while (list.length > AppConstants.maxRecents) {
      list.removeLast();
    }
    await _saveList(_recentsKey, list);
  }

  List<Place> _loadList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveList(String key, List<Place> places) async {
    await _prefs.setString(
      key,
      jsonEncode(places.map((p) => p.toJson()).toList()),
    );
  }
}
