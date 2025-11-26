import 'package:flutter/foundation.dart';

class AppData {
  // Demo playlists removed. Keep an empty list so UI can handle "no data".
  static final List<Map<String, dynamic>> playlists = [];
  // Global root tab notifier so independent pages can request switching
  // the main bottom navigation (0: Home, 1: Liked, 2: Library).
  static final ValueNotifier<int> rootTab = ValueNotifier<int>(0);
}
