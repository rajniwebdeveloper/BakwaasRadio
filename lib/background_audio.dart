import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'cache_helper.dart';
import 'audio_actions.dart';

/// A simple AudioHandler backed by just_audio. Exposes a small surface
/// suitable for background playback and notifications.
class BackgroundAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  Timer? _metadataTimer;
  final Duration _metadataInterval = const Duration(seconds: 60);

  BackgroundAudioHandler() {
    debugPrint('BackgroundAudioHandler: initializing');
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

    // Start periodic metadata updater which will poll stream metadata
    // (ICY) for live radio streams and update the active mediaItem so the
    // system notification shows current track info.
    _metadataTimer = Timer.periodic(_metadataInterval, (_) async {
      try {
        await _updateMetadataIfNeeded();
      } catch (_) {
        // ignore metadata errors
      }
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
  Future<void> play() {
    debugPrint('BackgroundAudioHandler: play called');
    return _player.play();
  }

  @override
  Future<void> pause() {
    debugPrint('BackgroundAudioHandler: pause called');
    return _player.pause();
  }

  @override
  Future<void> stop() async {
    debugPrint('BackgroundAudioHandler: stop called');
    _metadataTimer?.cancel();
    _metadataTimer = null;
    final res = await _player.stop();
    debugPrint('BackgroundAudioHandler: stop completed');
    return res;
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setUrl(String url, {Map<String, String>? extras}) async {
    debugPrint('BackgroundAudioHandler: setUrl called for $url');
    // prepare session
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // load source
    try {
      await _player.setUrl(url);
      final title = extras?['title'] ?? url;
      final artString = extras?['artUri'];
      var artUri = artString != null ? Uri.tryParse(artString) : null;
      mediaItem.add(MediaItem(
        id: url,
        album: extras?['album'],
        title: title,
        artUri: artUri,
      ));
      debugPrint('BackgroundAudioHandler: mediaItem added id=$url title=$title artUri=$artUri');

      // If artUri is a remote URL, attempt to cache it locally and update
      // the mediaItem so Android notification can use a local file:// URI
      // for its large icon (more reliable when the app process is killed).
      try {
        if (artUri != null && (artUri.scheme == 'http' || artUri.scheme == 'https')) {
          final cached = await CacheHelper.cacheImage(artUri.toString());
          if (cached != null && cached.isNotEmpty) {
            final item = mediaItem.value;
            if (item != null) {
              final updated = item.copyWith(artUri: Uri.file(cached));
              mediaItem.add(updated);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('art cache update failed: $e');
      }
    } catch (e) {
      debugPrint('setUrl error: $e');
      rethrow;
    }
  }

  /// Attempt to update metadata for the current stream (ICE/ICY metadata).
  /// If we find a new `StreamTitle` we update the `mediaItem` so the
  /// notification shows the latest song/track title.
  Future<void> _updateMetadataIfNeeded() async {
    final item = mediaItem.value;
    if (item == null) return;
    final url = item.id;
    if (url.isEmpty) return;

    try {
      final meta = await _fetchIcyMetadata(url);
      if (meta != null && meta.isNotEmpty) {
        final curTitle = item.title;
        if (meta != curTitle) {
          mediaItem.add(item.copyWith(title: meta));
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('metadata update failed: $e');
    }
  }

  /// Fetch ICY metadata (if available) for the given stream URL.
  /// Returns the `StreamTitle` or null if not available.
  Future<String?> _fetchIcyMetadata(String url) async {
    try {
      final uri = Uri.parse(url);
      final req = http.Request('GET', uri)
        ..headers['Icy-MetaData'] = '1'
        ..headers['User-Agent'] = 'BakwaasFM/1.0';
      final streamed = await http.Client().send(req).timeout(const Duration(seconds: 6));

      final headers = Map<String, String>.from(streamed.headers);
      // headers may include 'icy-metaint' or 'icy-metaint' in lowercase
      final metaIntHeader = headers.entries.firstWhere(
          (e) => e.key.toLowerCase() == 'icy-metaint', orElse: () => const MapEntry('', ''));
      final metaInt = int.tryParse(metaIntHeader.value) ?? 0;
      if (metaInt <= 0) {
        // No ICY metadata supported
        streamed.stream.drain();
        return null;
      }

      // Read metaInt bytes then one length byte and metadata block
        final reader = streamed.stream
          .transform(StreamTransformer<List<int>, List<int>>.fromHandlers(handleData: (data, sink) => sink.add(data)));
      final buffer = <int>[];
      final sub = reader.listen(null);
      try {
        // read until we have metaInt bytes
        while (buffer.length < metaInt) {
          final chunk = await streamed.stream.first.timeout(const Duration(milliseconds: 800));
          buffer.addAll(chunk);
        }
        // consume the meta length byte
        final lenByteList = await streamed.stream.first.timeout(const Duration(milliseconds: 800));
        final len = lenByteList.isNotEmpty ? lenByteList[0] : 0;
        final metaLen = len * 16;
        if (metaLen == 0) return null;
        // read metadata
        final metaBuf = <int>[];
        while (metaBuf.length < metaLen) {
          final chunk = await streamed.stream.first.timeout(const Duration(milliseconds: 800));
          metaBuf.addAll(chunk);
        }
        final metaStr = String.fromCharCodes(metaBuf).trim();
        // parse StreamTitle='Artist - Title';
        final match = RegExp(r"StreamTitle='([^']*)'").firstMatch(metaStr);
        if (match != null) {
          return match.group(1);
        }
      } finally {
        await sub.cancel();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ICY fetch error: $e');
    }
    return null;
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // simple single-item behavior for now
    this.mediaItem.add(mediaItem);
    await _player.setUrl(mediaItem.id);
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('BackgroundAudioHandler: skipToNext');
    try {
      AudioActions.onSkipNext?.call();
    } catch (e) {
      debugPrint('skipToNext callback failed: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('BackgroundAudioHandler: skipToPrevious');
    try {
      AudioActions.onSkipPrevious?.call();
    } catch (e) {
      debugPrint('skipToPrevious callback failed: $e');
    }
  }

  
}

/// Initialize and return an `AudioHandler` for use in app code.
/// This will also start the audio_service background task on supported
/// platforms so playback continues when the app is backgrounded/closed.
Future<AudioHandler> initBackgroundAudioHandler() async {
  return await AudioService.init(
    builder: () => BackgroundAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.bakwaas.fm.audio',
      androidNotificationChannelName: 'Bakwaas Audio',
      androidNotificationOngoing: true,
      // Keep the foreground service running when the app is paused/removed
      // from recents so playback can continue. This prevents the system from
      // stopping the service when the UI is destroyed.
      androidStopForegroundOnPause: false,
      // When notification is clicked resume the activity
      androidResumeOnClick: true,
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
