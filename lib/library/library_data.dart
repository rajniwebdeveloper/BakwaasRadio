import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models/station.dart';
import '../playback_manager.dart';

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
  // Error message when station loading fails (null when ok)
  static final ValueNotifier<String?> stationsError = ValueNotifier<String?>(null);

  /// Load live library data from backend. Currently fetches stations.
  static Future<void> load({bool forceRefresh = false, int retries = 3}) async {
    if (!forceRefresh && stations.value.isNotEmpty) return;
    stationsError.value = null;
    int attempt = 0;
    while (attempt < retries) {
      attempt++;
      try {
        final s = await ApiService.getStations();
        stations.value = s;
        stationsError.value = null;
        // ignore: avoid_print
        print('LibraryData.load: loaded ${s.length} stations (attempt $attempt)');
        return;
      } catch (e) {
        // include error text to help debugging
        stationsError.value = 'Failed to load stations (attempt $attempt): $e';
        // log full stack for developer console
        // ignore: avoid_print
        print('LibraryData.load error: $e');
        // exponential backoff
        await Future.delayed(Duration(milliseconds: 300 * (1 << (attempt - 1))));
      }
    }
    // All retries failed — keep last error message.
  }

  // Global filter set for Library page (keys: liked, albums, artists, downloads, playlists)
    // Default to show common sections including stations so users see live data
    static final ValueNotifier<Set<String>> filters =
      ValueNotifier<Set<String>>(<String>{'albums', 'artists', 'playlists', 'downloads', 'liked', 'stations', 'recent'});

    /// Return stations that match the currently playing (or last) song URL.
    /// Matches against `playerUrl`, `streamURL`, and `mp3Url` fields.
    static List<Station> nowPlayingStations() {
      final current = PlaybackManager.instance.currentSong ?? PlaybackManager.instance.lastSong;
      final url = current?['url'];
      if (url == null || url.isEmpty) return <Station>[];
      final normalized = url.trim();
      return stations.value.where((s) {
        final candidates = <String?>[s.playerUrl, s.streamURL, s.mp3Url];
        for (final c in candidates) {
          if (c == null) continue;
          if (c.trim() == normalized) return true;
          // Some backend player URLs wrap the original URL; a contains check
          // helps match proxied player URLs as well.
          if (c.contains(normalized) || normalized.contains(c)) return true;
        }
        return false;
      }).toList();
    }

    /// Log current now-playing stations to console (DevTools). Helpful for debugging.
    static void logNowPlayingStations() {
      final matches = nowPlayingStations();
      if (matches.isEmpty) {
        // ignore: avoid_print
        print('LibraryData: no matching stations for current playback');
        return;
      }
      // ignore: avoid_print
      print('LibraryData: now playing matches: ${matches.map((s) => s.name).join(', ')}');
    }
}
