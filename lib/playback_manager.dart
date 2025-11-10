import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class PlaybackManager extends ChangeNotifier {
  PlaybackManager._internal() {
    _audioPlayer = AudioPlayer();
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
  Map<String, String>? _currentSong;
  bool _isPlaying = false;
  double _progress = 0.0; // 0.0 - 1.0
  int _durationSeconds = 0;

  // Remember the last played song even when playback is stopped
  Map<String, String>? _lastSong;

  Map<String, String>? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  double get progress => _progress;
  int get durationSeconds => _durationSeconds;
  Map<String, String>? get lastSong =>
      _lastSong != null ? Map.from(_lastSong!) : null;

  void play(Map<String, String> song, {int duration = 0}) {
    if (song['url'] == null || song['url']!.isEmpty) {
      return;
    }

    // If same song and was paused, resume
    if (_currentSong != null &&
        _mapEquals(_currentSong!, song) &&
        !_isPlaying) {
      _audioPlayer.resume();
      return;
    }

    _currentSong = Map.from(song);
    _audioPlayer.play(UrlSource(song['url']!));
    _lastSong = Map.from(song);
    notifyListeners();
  }

  void pause() {
    _audioPlayer.pause();
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
    _audioPlayer.seek(Duration(seconds: position.round()));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
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
