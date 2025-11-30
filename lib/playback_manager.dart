import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:audio_service/audio_service.dart';
import 'background_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaybackManager extends ChangeNotifier {
  PlaybackManager._internal() {
    _audioPlayer = AudioPlayer();
    // Try to initialize the background audio handler. If that fails,
    // we continue to use the local AudioPlayer instance as a fallback.
    _initHandler();

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
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
  }
  static final PlaybackManager instance = PlaybackManager._internal();

  late final AudioPlayer _audioPlayer;
  AudioHandler? _audioHandler;
  Map<String, String>? _currentSong;
  bool _isPlaying = false;
  double _progress = 0.0; // 0.0 - 1.0
  int _durationSeconds = 0;

  // simple volume support to satisfy callers in UI
  double _volume = 1.0;

  // Remember the last played song even when playback is stopped
  Map<String, String>? _lastSong;
  // persisted history (most-recent-first)
  List<Map<String, String>> _history = [];

  Map<String, String>? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
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
        _isPlaying = state.playing;
        // update position/duration if available
        notifyListeners();
      });
      _audioHandler!.mediaItem.listen((item) {
        if (item != null) {
          _durationSeconds = item.duration?.inSeconds ?? _durationSeconds;
        }
        notifyListeners();
      });
    } catch (e) {
      // initialization failed; keep using local player as fallback
      _audioHandler = null;
    }
  }

  Future<void> play(Map<String, String> song, {int duration = 0}) async {
    if (song['url'] == null || song['url']!.isEmpty) {
      return;
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
      return;
    }

    _currentSong = Map.from(song);
    // Ensure handler is initialized (attempt again) before playback.
    if (_audioHandler == null) {
      await _initHandler();
    }

    if (_audioHandler != null) {
      try {
        final handler = _audioHandler as dynamic;
        // Prepare extras mapping: ensure artwork is passed as 'artUri'
        final extras = Map<String, String>.from(song);
        if (extras.containsKey('image') && !extras.containsKey('artUri')) {
          extras['artUri'] = extras['image']!;
        }
        await handler.setUrl(song['url']!, extras: extras);
        _audioHandler!.play();
      } catch (_) {
        // if the handler does not support setUrl, fall back
        _audioPlayer.play(UrlSource(song['url']!));
      }
    } else {
      _audioPlayer.play(UrlSource(song['url']!));
    }
    _lastSong = Map.from(song);
    // update history: push front and persist
    _addToHistory(Map.from(song));
    notifyListeners();
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

  void pause() {
    if (_audioHandler != null) {
      _audioHandler!.pause();
    } else {
      _audioPlayer.pause();
    }
  }

  void toggle() {
    if (_isPlaying) {
      pause();
    } else {
      if (_currentSong != null) {
        play(_currentSong!);
      }
    }
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
    _audioPlayer.dispose();
    _audioHandler?.stop();
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
