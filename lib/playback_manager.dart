import 'dart:async';
import 'package:flutter/foundation.dart';

class PlaybackManager extends ChangeNotifier {
  PlaybackManager._internal();
  static final PlaybackManager instance = PlaybackManager._internal();

  Map<String, String>? _currentSong;
  bool _isPlaying = false;
  double _progress = 0.0; // 0.0 - 1.0
  int _durationSeconds = 191; // default 3:11

  Timer? _timer;

  // Remember the last played song even when playback is stopped
  Map<String, String>? _lastSong;

  Map<String, String>? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  double get progress => _progress;
  int get durationSeconds => _durationSeconds;
  Map<String, String>? get lastSong =>
      _lastSong != null ? Map.from(_lastSong!) : null;

  void play(Map<String, String> song, {int duration = 191}) {
    // If same song and was paused, resume
    if (_currentSong != null &&
        _mapEquals(_currentSong!, song) &&
        _progress > 0.0) {
      _durationSeconds = duration;
      _startTimer();
      _isPlaying = true;
      notifyListeners();
      return;
    }

    _currentSong = Map.from(song);
    _durationSeconds = duration;
    _progress = 0.0;
    _isPlaying = true;
    _startTimer();
    // remember last played
    _lastSong = Map.from(song);
    notifyListeners();
  }

  void pause() {
    _stopTimer();
    _isPlaying = false;
    notifyListeners();
  }

  void toggle() {
    if (_isPlaying)
      pause();
    else {
      if (_currentSong != null) {
        _isPlaying = true;
        _startTimer();
        notifyListeners();
      }
    }
  }

  void seek(double value) {
    _progress = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPlaying) return;
      final step = 1 / (_durationSeconds <= 0 ? 1 : _durationSeconds);
      _progress += step;
      if (_progress >= 1.0) {
        _progress = 1.0;
        _isPlaying = false;
        _stopTimer();
      }
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || a[k] != b[k]) return false;
    }
    return true;
  }
}
