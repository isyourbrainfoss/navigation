import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/place.dart';

class FavoritesRepository {
  FavoritesRepository(this._prefs);

  static const _favoritesKey = 'navigation_favorites_v1';
  static const _recentsKey = 'navigation_recents_v1';
  static const _foldersKey = 'navigation_folders_v1';

  final SharedPreferences _prefs;

  static Future<FavoritesRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return FavoritesRepository(prefs);
  }

  List<Place> loadFavorites() => _loadList(_favoritesKey);

  List<Place> loadRecents() => _loadList(_recentsKey);

  List<String> loadFolders() {
    final raw = _prefs.getStringList(_foldersKey);
    if (raw == null || raw.isEmpty) return ['Starred'];
    return raw;
  }

  Future<void> saveFolders(List<String> folders) async {
    var list = List<String>.of(folders);
    if (!list.contains('Starred')) list = ['Starred', ...list];
    while (list.length > AppConstants.maxBookmarkFolders) {
      list.removeLast();
    }
    await _prefs.setStringList(_foldersKey, list);
  }

  Future<void> addFolder(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    final list = loadFolders();
    if (!list.contains(n)) list.add(n);
    await saveFolders(list);
  }

  Place? placeWithRole(PlaceRole role) {
    for (final p in loadFavorites()) {
      if (p.role == role) return p;
    }
    return null;
  }

  Future<void> setRole(Place place, PlaceRole role) async {
    final list = loadFavorites();
    list.removeWhere((p) => p.role == role || p.id == place.id);
    list.insert(0, place.copyWith(role: role));
    await _saveList(_favoritesKey, list);
  }

  Future<void> clearRole(PlaceRole role) async {
    final list = loadFavorites();
    for (var i = 0; i < list.length; i++) {
      if (list[i].role == role) {
        list[i] = list[i].copyWith(role: PlaceRole.none);
      }
    }
    await _saveList(_favoritesKey, list);
  }

  Future<void> addFavorite(Place place, {String group = 'Starred'}) async {
    final list = loadFavorites();
    PlaceRole existingRole = PlaceRole.none;
    for (final p in list) {
      if (p.id == place.id) existingRole = p.role;
    }
    list.removeWhere((p) => p.id == place.id);
    list.insert(
      0,
      place.copyWith(
        group: group.isEmpty ? 'Starred' : group,
        role: place.role == PlaceRole.none ? existingRole : place.role,
      ),
    );
    while (list.length > AppConstants.maxFavorites) {
      list.removeLast();
    }
    await _saveList(_favoritesKey, list);
    final folders = loadFolders();
    final g = group.isEmpty ? 'Starred' : group;
    if (!folders.contains(g)) {
      await addFolder(g);
    }
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
