import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';

/// Избранное — порт `useFavorites` (zustand+persist) на Riverpod.
/// Ключи универсальные: `product:<id>`, `service:coffee` и т.п.
/// Персист в SharedPreferences под ключом `bemboks-fav` (как на вебе).
class FavoritesController extends Notifier<Set<String>> {
  static const _key = 'bemboks-fav';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Set<String> build() {
    final raw = _prefs.getString(_key);
    if (raw == null) return <String>{};
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final items = (j['items'] as Map?) ?? const {};
      return items.entries.where((e) => e.value == true).map((e) => e.key.toString()).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  bool has(String key) => state.contains(key);

  void toggle(String key) {
    final next = {...state};
    if (!next.add(key)) next.remove(key);
    state = next;
    _persist();
  }

  void _persist() {
    final items = {for (final k in state) k: true};
    _prefs.setString(_key, jsonEncode({'items': items}));
  }
}

final favoritesProvider = NotifierProvider<FavoritesController, Set<String>>(FavoritesController.new);
