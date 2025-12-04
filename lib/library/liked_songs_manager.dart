import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LikedSongsManager {
  // ValueNotifier so UI can listen for changes
  static final ValueNotifier<List<Map<String, String>>> liked =
      ValueNotifier([]);

  static const String _prefsKey = 'bakwaas_liked_songs_v1';

  /// Load persisted liked songs from SharedPreferences. Safe to call multiple times.
  static Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        liked.value = decoded.map<Map<String, String>>((e) => Map<String, String>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('LikedSongsManager: failed to load persisted likes: $e');
    }
  }

  static Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(liked.value);
      await prefs.setString(_prefsKey, raw);
    } catch (e) {
      debugPrint('LikedSongsManager: failed to save likes: $e');
    }
  }

  static void add(Map<String, String> song) {
    final list = List<Map<String, String>>.from(liked.value);
    final exists = list.any((s) =>
        s['title'] == song['title'] && s['subtitle'] == song['subtitle']);
    if (!exists) {
      list.insert(0, song);
      liked.value = list;
      // persist
      _saveToPrefs();
    }
  }

  static void remove(Map<String, String> song) {
    final list = List<Map<String, String>>.from(liked.value);
    list.removeWhere((s) =>
        s['title'] == song['title'] && s['subtitle'] == song['subtitle']);
    liked.value = list;
    _saveToPrefs();
  }

  static void clear() {
    liked.value = [];
    _saveToPrefs();
  }

  static bool contains(Map<String, String> song) {
    return liked.value.any((s) =>
        s['title'] == song['title'] && s['subtitle'] == song['subtitle']);
  }
}
