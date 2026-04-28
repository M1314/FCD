import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the set of lesson IDs that the user has marked as favourites.
/// Data is stored per user so that switching accounts keeps things tidy.
class FavoritesStorage {
  static const String _prefix = 'favorites_v1_user_';

  Future<Set<int>> getFavorites(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$userId');
    if (raw == null) {
      return <int>{};
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<int>().toSet();
    } catch (_) {
      return <int>{};
    }
  }

  /// Removes [lessonId] from favourites. No-op if it is not currently favourited.
  Future<void> removeFavorite(int userId, int lessonId) async {
    final favorites = await getFavorites(userId);
    if (!favorites.remove(lessonId)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$userId',
      jsonEncode(favorites.toList()),
    );
  }

  /// Toggles the favourite state for [lessonId] and returns the new state.
  Future<bool> toggleFavorite(int userId, int lessonId) async {
    final favorites = await getFavorites(userId);
    final nowFavorite = !favorites.contains(lessonId);
    if (nowFavorite) {
      favorites.add(lessonId);
    } else {
      favorites.remove(lessonId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$userId',
      jsonEncode(favorites.toList()),
    );
    return nowFavorite;
  }
}
