import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:audio_service/audio_service.dart';
import 'background_audio.dart';
import 'audio_actions.dart';
import 'package:flutter/services.dart';
import 'cache_helper.dart';
import 'app_data.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'library/library_data.dart';
import 'models/station.dart';
import 'library/liked_songs_manager.dart';

class PlaybackManager extends ChangeNotifier {
  PlaybackManager._internal() {
    _audioPlayer = AudioPlayer();
    // NOTE: Do NOT initialize the background audio handler automatically.
    // Some deployments prefer not to use the background player or notification
    // area. Keep handler initialization available but explicit; by default
    // we continue using the local AudioPlayer instance as fallback.

    _audioPlayer.onDurationChanged.listen((duration) {
      _durationSeconds = duration.inSeconds;
      notifyListeners();
    });
    _audioPlayer.onPositionChanged.listen((position) {
      _progress = _durationSeconds > 0
          ? position.inSeconds / _durationSeconds
          : 0.0;
      notifyListeners();
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state == PlayerState.playing;
      // Any explicit player state update should clear the "loading"
      // indicator unless the underlying player exposes a separate
      // buffering/loading status (audio_service handles that for
      // background handler). This avoids the UI showing a perpetual
      // spinner when playback failed to start.
      _isLoading = false;
      notifyListeners();
      // If playback stopped unexpectedly (not user-paused), try reconnecting
      if (!wasPlaying && !_isPlaying && !_manuallyPaused && _currentSong != null) {
        // increment attempt counter and either retry or trigger auto-next
        _reconnectAttempts++;
        if (_reconnectAttempts <= _maxReconnectAttempts) {
          final attempt = _reconnectAttempts;
          Future.delayed(Duration(milliseconds: 400 * attempt), () async {
            try {
              await play(_currentSong!);
            } catch (_) {}
          });
        } else {
          // exceeded retries -> clear loading and notify UI, then ask UI to play next
          _isLoading = false;
          notifyListeners();
          _reconnectAttempts = 0;
          try {
            if (onAutoNext != null) onAutoNext!();
          } catch (_) {}
        }
      }
    });

    // Listen for native notification actions invoked from Android
    // MainActivity will forward notification intents as a method call
    // named 'notificationAction' on the 'com.bakwaas.fm/keepalive' channel.
    try {
      _keepAliveChannel.setMethodCallHandler((call) async {
        if (call.method == 'notificationAction') {
          final arg = call.arguments;
          final action = arg is String ? arg : (arg?.toString() ?? '');
          debugPrint('PlaybackManager: received native notificationAction -> $action');
          // Debounce: ignore repeated identical actions received within a short window
          // Some devices/ROMs may deliver both a media key event and also start
          // the activity which forwards the same action; this prevents double-handling.
          final now = DateTime.now().millisecondsSinceEpoch;
          try {
            if (_lastNotificationAction != null && _lastNotificationAction == action && (now - _lastNotificationActionAtMs) < 600) {
              debugPrint('PlaybackManager: ignored duplicate notificationAction -> $action');
              return null;
            }
          } catch (_) {}
          _lastNotificationAction = action;
          _lastNotificationActionAtMs = now;
          if (action == 'play' || action == 'pause' || action == 'toggle' || action == 'play_pause') {
            // If background handler is available prefer it, otherwise act on the local player directly.
            if (_audioHandler != null) {
              toggle();
            } else {
              // Direct local control
              if (_isPlaying) {
                pause();
              } else {
                // If no current song selected, use lastSong as fallback
                final toPlay = _currentSong ?? _lastSong;
                if (toPlay != null) {
                  _manuallyPaused = false;
                  // fire-and-forget
                  play(toPlay);
                }
              }
            }
          } else if (action == 'next' || action == 'skipNext') {
            // direct next
            await playNextStation();
          } else if (action == 'previous' || action == 'prev' || action == 'skipPrevious') {
            await playPreviousStation();
          }
          } else if (call.method == 'openPlayer') {
            // Open the full player UI and start playback if a URL was provided.
            try {
              final mapArg = call.arguments as Map?;
              if (mapArg != null) {
                final songMap = <String, dynamic>{};
                mapArg.forEach((k, v) {
                  if (v != null) songMap[k.toString()] = v;
                });
                // Prefer station semantics if a URL is provided
                await AppData.openPlayerWith(song: songMap);
              }
            } catch (e) {
              // ignore failures
            }
        }
        return null;
      });
    } catch (e) {
      debugPrint('PlaybackManager: error setting keepAlive handler: $e');
    }
      // Drain any pending notification action that the native side cached
      // while the Dart isolate was starting. This ensures actions aren't
      // lost if they arrived before the MethodChannel handler was ready.
      try {
        _keepAliveChannel.invokeMethod<String>('getPendingNotificationAction').then((pending) {
          if (pending == null || pending.isEmpty) return;
          debugPrint('PlaybackManager: processing pending notificationAction -> $pending');
          final action = pending;
          final now = DateTime.now().millisecondsSinceEpoch;
          try {
            if (_lastNotificationAction != null && _lastNotificationAction == action && (now - _lastNotificationActionAtMs) < 600) {
              debugPrint('PlaybackManager: ignored duplicate pending notificationAction -> $action');
              return;
            }
            _lastNotificationAction = action;
            _lastNotificationActionAtMs = now;
            if (action == 'play' || action == 'pause' || action == 'toggle' || action == 'play_pause') {
              if (_audioHandler != null) {
                toggle();
              } else {
                if (_isPlaying) {
                  pause();
                } else {
                  final toPlay = _currentSong ?? _lastSong;
                  if (toPlay != null) {
                    _manuallyPaused = false;
                    play(toPlay);
                  }
                }
              }
            } else if (action == 'next' || action == 'skipNext') {
              playNextStation();
            } else if (action == 'previous' || action == 'prev' || action == 'skipPrevious') {
              playPreviousStation();
            }
          } catch (e) {
            // ignore errors handling pending action
          }
        }).catchError((_) {
          // ignore if native doesn't implement
        });
      } catch (e) {
        // ignore if native side doesn't implement this method or other errors
      }
  }
  static final PlaybackManager instance = PlaybackManager._internal();

  static const MethodChannel _keepAliveChannel = MethodChannel('com.bakwaas.fm/keepalive');

  late final AudioPlayer _audioPlayer;
  AudioHandler? _audioHandler;
  Map<String, String>? _currentSong;
  bool _isPlaying = false;
  bool _isLoading = false;
  double _progress = 0.0; // 0.0 - 1.0
  int _durationSeconds = 0;

  // Last notification action received and timestamp (ms) for debounce
  String? _lastNotificationAction;
  int _lastNotificationActionAtMs = 0;

  // simple volume support to satisfy callers in UI
  double _volume = 1.0;

  // reconnect state
  bool _manuallyPaused = false;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  /// Optional callback invoked when playback failed after max retries.
  /// UI code can register a handler to advance to the next track/station.
  void Function()? onAutoNext;

  // Remember the last played song even when playback is stopped
  Map<String, String>? _lastSong;
  // persisted history (most-recent-first)
  List<Map<String, String>> _history = [];
  // Optional timer used for short preview playback (auto-pause)
  Timer? _previewTimer;

  Map<String, String>? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  double get progress => _progress;
  int get durationSeconds => _durationSeconds;
  Map<String, String>? get lastSong =>
      _lastSong != null ? Map.from(_lastSong!) : null;

  double get volume => _volume;

  List<Map<String, String>> get history => List.unmodifiable(_history);

  // Load persisted state (lastSong and history)
  Future<void> loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastJson = prefs.getString('last_song');
      if (lastJson != null && lastJson.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(lastJson);
        _lastSong = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      final histJson = prefs.getStringList('play_history') ?? [];
      _history = histJson.map((s) {
        final m = json.decode(s) as Map<String, dynamic>;
        return m.map((k, v) => MapEntry(k.toString(), v.toString()));
      }).toList();
    } catch (_) {
      // ignore errors and keep defaults
    }
  }

  Future<void> _initHandler() async {
    try {
      // Request notification permission on Android 13+ so the service
      // notification is allowed before starting the background handler.
      try {
        await requestNotificationPermission();
      } catch (_) {}

      _audioHandler = await initBackgroundAudioHandler();
      // subscribe to handler streams to reflect state in the manager
      _audioHandler!.playbackState.listen((state) {
        debugPrint('PlaybackManager: playbackState received from handler: playing=${state.playing} processingState=${state.processingState}');
        _isPlaying = state.playing;
        // reflect audio_service processing state as loading flag
        _isLoading = state.processingState == AudioProcessingState.loading;
        // update position/duration if available
        notifyListeners();
      });
      _audioHandler!.mediaItem.listen((item) {
        debugPrint('PlaybackManager: mediaItem received from handler: $item');
        if (item != null) {
          _durationSeconds = item.duration?.inSeconds ?? _durationSeconds;
        }
        notifyListeners();
      });
      // Wire notification skip actions back to the manager
      AudioActions.onSkipNext = () {
        try {
          playNextStation();
        } catch (_) {}
      };
      AudioActions.onSkipPrevious = () {
        try {
          playPreviousStation();
        } catch (_) {}
      };
    } catch (e) {
      // initialization failed; keep using local player as fallback
      _audioHandler = null;
    }
  }

  /// Play the next station. Uses the loaded `LibraryData.stations` list
  /// to advance from the current station when possible, otherwise picks
  /// a random station.
  Future<void> playNextStation() async {
    // Prefer the user's liked songs list if it contains multiple entries.
    final liked = LikedSongsManager.liked.value;
    final stations = LibraryData.stations.value;
    if (stations.isEmpty && liked.isEmpty) return;
    final currentUrl = _currentSong?['url'] ?? _lastSong?['url'];
    int found = -1;
    // If the liked list has at least 2 items, use it as the playlist source.
    if (liked.length >= 2) {
      // Try to find current in liked list
      if (currentUrl != null) {
        for (var i = 0; i < liked.length; i++) {
          final s = liked[i];
          final c = s['url'];
          if (c != null && currentUrl.contains(c) || (c != null && c.contains(currentUrl))) {
            found = i;
            break;
          }
        }
      }
      Map<String, String> nextMap;
      if (found != -1) {
        nextMap = liked[(found + 1) % liked.length];
      } else {
        nextMap = liked[math.Random().nextInt(liked.length)];
      }
      try {
        await play(nextMap);
      } catch (_) {}
      return;
    }

    if (stations.isEmpty) return;

    if (currentUrl != null) {
      for (var i = 0; i < stations.length; i++) {
        final s = stations[i];
        final candidates = <String?>[s.playerUrl, s.streamURL, s.mp3Url];
        for (final c in candidates) {
          if (c == null) continue;
          if (c.trim() == currentUrl.trim() || c.contains(currentUrl) || currentUrl.contains(c)) {
            found = i;
            break;
          }
        }
        if (found != -1) break;
      }
    }

    Station nextStation;
    if (found != -1) {
      nextStation = stations[(found + 1) % stations.length];
    } else {
      nextStation = stations[math.Random().nextInt(stations.length)];
    }
    final url = nextStation.playerUrl ?? nextStation.streamURL ?? nextStation.mp3Url ?? '';
    if (url.isEmpty) return;
    final song = {
      'title': nextStation.name,
      'subtitle': nextStation.description ?? '',
      'image': nextStation.profilepic ?? '',
      'url': url,
    };
    try {
      await play(song);
    } catch (_) {}
  }

  /// Play previous station based on history, or random fallback.
  Future<void> playPreviousStation() async {
    final history = _history;
    if (history.length >= 2) {
      final prev = history[1];
      try {
        await play(prev);
      } catch (_) {}
      return;
    }
    final stations = LibraryData.stations.value;
    if (stations.isEmpty) return;
    final s = stations[math.Random().nextInt(stations.length)];
    final url = s.playerUrl ?? s.streamURL ?? s.mp3Url ?? '';
    if (url.isEmpty) return;
    final song = {
      'title': s.name,
      'subtitle': s.description ?? '',
      'image': s.profilepic ?? '',
      'url': url,
    };
    try {
      await play(song);
    } catch (_) {}
  }

  /// Ensure the background audio handler is initialized.
  /// Public wrapper so callers (e.g. app startup) can eagerly start
  /// the audio_service background task and notification channel.
  Future<void> ensureBackgroundHandler() async {
    if (_audioHandler == null) {
      await _initHandler();
    }
  }

  /// Start the native Android keep-alive foreground service.
  /// Safe no-op on platforms where the method channel is not available.
  Future<void> startNativeKeepAlive() async {
    try {
      await _keepAliveChannel.invokeMethod('startService');
    } on MissingPluginException {
      // The platform implementation may not be registered in some
      // execution contexts (for example during background isolates
      // or early startup). This is non-fatal; ignore quietly.
    } catch (e) {
      // Log other unexpected errors for debugging
      debugPrint('startNativeKeepAlive failed: $e');
    }
  }

  /// Start the native keep-alive foreground service with metadata so the
  /// native notification can display title/subtitle/artwork when audio
  /// is played using the local player (audio_service unavailable).
  Future<void> startNativeKeepAliveWithMeta(Map<String, String> meta) async {
    try {
      await _keepAliveChannel.invokeMethod('startService', meta);
    } on MissingPluginException {
      // ignore
    } catch (e) {
      debugPrint('startNativeKeepAliveWithMeta failed: $e');
    }
  }

  /// Stop the native Android keep-alive foreground service.
  Future<void> stopNativeKeepAlive() async {
    try {
      await _keepAliveChannel.invokeMethod('stopService');
    } on MissingPluginException {
      // Platform implementation not available (early startup/background isolate).
      // Treat this as a no-op and avoid noisy logging.
    } catch (e) {
      // Other errors are useful for debugging.
      debugPrint('stopNativeKeepAlive failed: $e');
    }
  }

  /// Returns true if the background audio service is available and running.
  Future<bool> _audioServiceAvailable() async {
    // Treat the presence of a non-null audio handler as availability.
    return _audioHandler != null;
  }

  Future<bool> play(Map<String, String> song, {int duration = 0}) async {
    if (song['url'] == null || song['url']!.isEmpty) {
      return false;
    }

    // If same song and was paused, resume
    if (_currentSong != null &&
        _mapEquals(_currentSong!, song) &&
        !_isPlaying) {
      if (_audioHandler != null) {
        _audioHandler!.play();
      } else {
        _audioPlayer.resume();
      }
      _manuallyPaused = false;
      return true;
    }

    _currentSong = Map.from(song);
    _manuallyPaused = false;
    _reconnectAttempts = 0;
    _isLoading = true;
    // cancel any previous preview timer when a new play request is made
    _previewTimer?.cancel();
    notifyListeners();
    // Ensure handler is initialized (attempt again) before playback.
    if (_audioHandler == null) {
      await _initHandler();
    }

    // Helper to wait briefly for player to report playing state
    Future<bool> waitForPlaying({int timeoutMs = 2000}) async {
      final sw = DateTime.now();
      while (DateTime.now().difference(sw).inMilliseconds < timeoutMs) {
        if (_isPlaying) return true;
        await Future.delayed(const Duration(milliseconds: 200));
      }
      return _isPlaying;
    }

    if (await _audioServiceAvailable()) {
      debugPrint('PlaybackManager.play: attempting background handler for ${song['url']}');
      try {
        final handler = _audioHandler as dynamic;
        final extras = Map<String, String>.from(song);
        // If an image URL is provided, try to cache it locally and provide
        // a file:// URI for the notification so Android can show a large
        // artwork icon even if the app process is killed.
        if (extras.containsKey('image') && !extras.containsKey('artUri')) {
          try {
            final cached = await CacheHelper.cacheImage(extras['image']!);
            if (cached != null && cached.isNotEmpty) {
              extras['artUri'] = Uri.file(cached).toString();
            } else {
              extras['artUri'] = extras['image']!;
            }
          } catch (_) {
            extras['artUri'] = extras['image']!;
          }
        }
        // Try the background audio handler several times (best-effort).
        // Some devices or networks may cause the handler to fail briefly,
        // so attempt up to `_maxReconnectAttempts` before falling back
        // to the local player implementation.
        bool bgOk = false;
        for (var attempt = 1; attempt <= _maxReconnectAttempts; attempt++) {
          try {
            await handler.setUrl(song['url']!, extras: extras);
            await handler.play();
            final ok = await waitForPlaying(timeoutMs: 2500);
            if (ok) {
              bgOk = true;
              break;
            }
          } catch (e) {
            // ignore and retry after a small backoff
          }
          // small backoff between attempts
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }

        _isLoading = false;
        if (bgOk) {
          _isPlaying = true;
          // Ensure native keep-alive foreground service is running so the
          // notification and background sync persist even if the Flutter
          // UI process is backgrounded. Best-effort; ignore errors.
          try {
            final meta = <String, String>{
              'title': song['title'] ?? 'Bakwaas FM',
              'subtitle': song['subtitle'] ?? 'Live Radio',
              'isPlaying': 'true',
              'loading': 'false',
            };
            if (extras.containsKey('artUri')) meta['artUri'] = extras['artUri'] as String;
            await startNativeKeepAliveWithMeta(meta);
          } catch (_) {}
          _lastSong = Map.from(song);
          _addToHistory(Map.from(song));
          // schedule preview auto-pause when requested
          if (duration > 0) {
            _previewTimer?.cancel();
            _previewTimer = Timer(Duration(seconds: duration), () {
              try {
                pause();
              } catch (_) {}
            });
          }
          notifyListeners();
          return true;
        }
        notifyListeners();
        // fall through to local player fallback
      } catch (_) {
        // fall through to local player fallback
      }
    }
    debugPrint('PlaybackManager.play: falling back to local player for ${song['url']}');

    try {
      // Inform native notification that we're buffering/loading for local fallback
      try {
        final loadingMeta = <String, String>{
          'title': song['title'] ?? 'Bakwaas FM',
          'subtitle': song['subtitle'] ?? 'Live Radio',
          'loading': 'true',
          'isPlaying': 'false',
        };
        if (song.containsKey('image') && song['image'] != null && song['image']!.isNotEmpty) {
          try {
            final cached = await CacheHelper.cacheImage(song['image']!);
            if (cached != null && cached.isNotEmpty) loadingMeta['artUri'] = Uri.file(cached).toString();
          } catch (_) {}
        }
        await startNativeKeepAliveWithMeta(loadingMeta);
      } catch (_) {}

      await _audioPlayer.play(UrlSource(song['url']!));
      final ok = await waitForPlaying();
      _isLoading = false;
      if (ok) {
        _isPlaying = true;
        _lastSong = Map.from(song);
        _addToHistory(Map.from(song));
        // Ensure native keep-alive notification shows even when using local player.
        try {
          final meta = <String, String>{
            'title': song['title'] ?? 'Bakwaas FM',
            'subtitle': song['subtitle'] ?? 'Live Radio',
            'isPlaying': 'true',
            'loading': 'false',
          };
          if (song.containsKey('image') && song['image'] != null && song['image']!.isNotEmpty) {
            try {
              final cached = await CacheHelper.cacheImage(song['image']!);
              if (cached != null && cached.isNotEmpty) meta['artUri'] = Uri.file(cached).toString();
            } catch (_) {}
          }
          await startNativeKeepAliveWithMeta(meta);
        } catch (_) {}
        // schedule preview auto-pause when requested
        if (duration > 0) {
          _previewTimer?.cancel();
          _previewTimer = Timer(Duration(seconds: duration), () {
            try {
              pause();
            } catch (_) {}
          });
        }
        notifyListeners();
        return true;
      }
      notifyListeners();
      return false;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _addToHistory(Map<String, String> song) async {
    try {
      // remove duplicates by url
      _history.removeWhere((s) => s['url'] == song['url']);
      _history.insert(0, song);
      // cap history
      if (_history.length > 200) _history = _history.sublist(0, 200);
      final prefs = await SharedPreferences.getInstance();
      final list = _history.map((m) => json.encode(m)).toList();
      await prefs.setStringList('play_history', list);
      await prefs.setString('last_song', json.encode(_lastSong ?? {}));
    } catch (_) {}
  }

  Future<void> pause() async {
    _manuallyPaused = true;
    _isLoading = false;
    // cancel any preview timer if user paused
    _previewTimer?.cancel();
    if (_audioHandler != null) {
      _audioHandler!.pause();
    } else {
      _audioPlayer.pause();
    }
    _isPlaying = false;
    notifyListeners();
    // Stop the keep-alive service when playback is paused/stopped to avoid
    // leaving an unnecessary foreground notification running.
    try {
      final meta = <String, String>{
        'title': _currentSong?['title'] ?? _lastSong?['title'] ?? 'Bakwaas FM',
        'subtitle': _currentSong?['subtitle'] ?? _lastSong?['subtitle'] ?? 'Paused',
        'isPlaying': 'false',
        'loading': 'false',
      };
      if (_currentSong != null && _currentSong!.containsKey('image')) {
        try {
          final cached = await CacheHelper.cacheImage(_currentSong!['image'] ?? '');
          if (cached != null && cached.isNotEmpty) meta['artUri'] = Uri.file(cached).toString();
        } catch (_) {}
      }
      await startNativeKeepAliveWithMeta(meta);
    } catch (_) {}
  }

  void toggle() {
    if (_isPlaying) {
      pause();
      return;
    }
    // If no current song is selected, fall back to the last played song
    // so the play button still resumes something sensible.
    if (_currentSong != null) {
      _manuallyPaused = false;
      play(_currentSong!);
      return;
    }
    if (_lastSong != null) {
      _manuallyPaused = false;
      play(_lastSong!);
      return;
    }
    // No song available to play — nothing to do. UI may handle this case.
  }

  void seek(double value) {
    final position = value * _durationSeconds;
    if (_audioHandler != null) {
      _audioHandler!.seek(Duration(seconds: position.round()));
    } else {
      _audioPlayer.seek(Duration(seconds: position.round()));
    }
  }

  /// Set player volume (0.0 - 1.0)
  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    try {
      if (_audioHandler != null) {
        try {
          final handler = _audioHandler as dynamic;
          handler.setVolume(_volume);
        } catch (_) {
          _audioPlayer.setVolume(_volume);
        }
      } else {
        _audioPlayer.setVolume(_volume);
      }
    } catch (_) {
      // ignore if underlying player doesn't support setVolume
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _audioPlayer.dispose();
    _audioHandler?.stop();
    // Clear audio action callbacks
    AudioActions.onSkipNext = null;
    AudioActions.onSkipPrevious = null;
    super.dispose();
  }

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || a[k] != b[k]) return false;
    }
    return true;
  }
}
