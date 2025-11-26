import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models/station.dart';

class LibraryData {
  static final ValueNotifier<List<Map<String, String>>> albums = ValueNotifier([
    {
      'title': 'Once Upon A Time In Mumbaai',
      'image': 'https://picsum.photos/200?image=11'
    },
    {'title': 'Romantic Hits', 'image': 'https://picsum.photos/200?image=12'},
  ]);

  static final ValueNotifier<List<Map<String, String>>> artists =
      ValueNotifier([
    {'name': 'Vishal Mishra'},
    {'name': 'Armaan Malik'},
  ]);

  static final ValueNotifier<List<Map<String, String>>> downloads =
      ValueNotifier(<Map<String, String>>[]);

  static final ValueNotifier<List<Map<String, String>>> playlists =
      ValueNotifier([
    {'title': 'Starred Songs', 'image': 'https://picsum.photos/200?image=15'},
    {'title': '#JioSaavnReplay', 'image': 'https://picsum.photos/200?image=16'},
  ]);

  // Live stations fetched from backend
  static final ValueNotifier<List<Station>> stations = ValueNotifier(<Station>[]);

  /// Load live library data from backend. Currently fetches stations.
  static Future<void> load() async {
    try {
      final s = await ApiService.getStations();
      stations.value = s;
    } catch (_) {
      // ignore - leave empty list
    }
  }

  // Global filter set for Library page (keys: liked, albums, artists, downloads, playlists)
    // Default to show common sections including stations so users see live data
    static final ValueNotifier<Set<String>> filters =
      ValueNotifier<Set<String>>(<String>{'albums', 'artists', 'playlists', 'downloads', 'liked', 'stations'});
}
