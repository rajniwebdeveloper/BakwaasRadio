import 'package:flutter/material.dart';

class LikedSongsManager {
  // ValueNotifier so UI can listen for changes
  static final ValueNotifier<List<Map<String, String>>> liked =
      ValueNotifier([]);

  static void add(Map<String, String> song) {
    final list = List<Map<String, String>>.from(liked.value);
    final exists = list.any((s) =>
        s['title'] == song['title'] && s['subtitle'] == song['subtitle']);
    if (!exists) {
      list.insert(0, song);
      liked.value = list;
    }
  }

  static void remove(Map<String, String> song) {
    final list = List<Map<String, String>>.from(liked.value);
    list.removeWhere((s) =>
        s['title'] == song['title'] && s['subtitle'] == song['subtitle']);
    liked.value = list;
  }

  static void clear() {
    liked.value = [];
  }

  static bool contains(Map<String, String> song) {
    return liked.value.any((s) =>
        s['title'] == song['title'] && s['subtitle'] == song['subtitle']);
  }
}
