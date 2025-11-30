import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// A simple AudioHandler backed by just_audio. Exposes a small surface
/// suitable for background playback and notifications.
class BackgroundAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  BackgroundAudioHandler() {
    // Forward player events to the audio_service clients
    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      final processingState = state.processingState;
      playbackState.add(playbackState.value.copyWith(
        playing: playing,
        processingState: _mapProcessingState(processingState),
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
      ));
    });

    _player.durationStream.listen((d) {
      final item = mediaItem.value;
      if (item != null) {
        mediaItem.add(item.copyWith(duration: d));
      }
    });

    _player.positionStream.listen((pos) {
      final state = playbackState.value;
      playbackState.add(state.copyWith(updatePosition: pos));
    });
  }

  AudioProcessingState _mapProcessingState(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return AudioProcessingState.loading;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setUrl(String url, {Map<String, String>? extras}) async {
    // prepare session
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // load source
    try {
      await _player.setUrl(url);
      final title = extras?['title'] ?? url;
      mediaItem.add(MediaItem(
        id: url,
        album: extras?['album'],
        title: title,
        artUri: extras?['artUri'] != null ? Uri.tryParse(extras!['artUri']!) : null,
      ));
    } catch (e) {
      if (kDebugMode) print('setUrl error: $e');
      rethrow;
    }
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // simple single-item behavior for now
    this.mediaItem.add(mediaItem);
    await _player.setUrl(mediaItem.id);
  }

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}
}

/// Initialize and return an `AudioHandler` for use in app code.
/// This will also start the audio_service background task on supported
/// platforms so playback continues when the app is backgrounded/closed.
Future<AudioHandler> initBackgroundAudioHandler() async {
  return await AudioService.init(
    builder: () => BackgroundAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.bakwaas.audio',
      androidNotificationChannelName: 'Bakwaas Audio',
      androidNotificationOngoing: true,
      // Use a small notification icon (add this to your Android drawable)
      androidNotificationIcon: 'drawable/ic_stat_bakwaas',
      androidNotificationClickStartsActivity: true,
    ),
  );
}

/// Request notification permission on Android 13+ so the foreground
/// service notification shows without being blocked. Call this early
/// (for example, on app start) before starting playback.
Future<void> requestNotificationPermission() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }
}
