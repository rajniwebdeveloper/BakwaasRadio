// Updated: Background audio handler tuned for audio_service + just_audio
// Ensures proper audio session activation, notification foreground service
// management, and metadata updates for lock-screen and notification controls.
import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'cache_helper.dart';
import 'audio_actions.dart';

/// A simple AudioHandler backed by just_audio. Exposes a small surface
/// suitable for background playback and notifications.
class BackgroundAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  Timer? _metadataTimer;
  AudioSession? _session;
  final List<MediaItem> _queue = <MediaItem>[];
  int _currentIndex = -1;
  final Duration _metadataInterval = const Duration(seconds: 60);
  static const MethodChannel _keepAliveChannel = MethodChannel('com.bakwaas.fm/keepalive');
  BackgroundAudioHandler() {
    debugPrint('BackgroundAudioHandler: initializing');
    // Configure audio session and playback event handling asynchronously.
    // Initialize a sensible default playback state so the system
    // has a consistent starting state before the player emits events.
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 3],
      systemActions: const {MediaAction.seek},
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      speed: 1.0,
    ));

    _init();
    // Periodic metadata updater for live streams (ICY metadata)
    _metadataTimer = Timer.periodic(_metadataInterval, (_) async {
      try {
        await _updateMetadataIfNeeded();
      } catch (_) {
        // ignore metadata errors
      }
    });
  }

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      _session = session;
      await session.configure(const AudioSessionConfiguration.music());
      // Keep local copies of last-known positions so we can populate
      // playbackState consistently from the playerState stream.
      Duration lastPosition = Duration.zero;
      Duration lastBuffered = Duration.zero;

      _player.positionStream.listen((pos) {
        lastPosition = pos;
        final state = playbackState.value;
        playbackState.add(state.copyWith(updatePosition: pos));
      });

      _player.bufferedPositionStream.listen((buf) {
        lastBuffered = buf;
        final state = playbackState.value;
        playbackState.add(state.copyWith(bufferedPosition: buf));
      });

      _player.playerStateStream.listen((state) {
        final playing = state.playing;
        final processingState = state.processingState;
        playbackState.add(playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          androidCompactActionIndices: const [0, 1, 3],
          systemActions: const {MediaAction.seek},
          processingState: _mapProcessingState(processingState),
          playing: playing,
          updatePosition: lastPosition,
          bufferedPosition: lastBuffered,
          speed: _player.speed,
        ));
      });

      // Update duration when available
      _player.durationStream.listen((d) {
        final item = mediaItem.value;
        if (item != null && d != null) {
          mediaItem.add(item.copyWith(duration: d));
        }
      });
    } catch (e) {
      debugPrint('BackgroundAudioHandler: init failed: $e');
    }
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
  Future<void> play() async {
    debugPrint('BackgroundAudioHandler: play called');
    try {
      await _player.play();
    } catch (e) {
      debugPrint('BackgroundAudioHandler: play error: $e');
      rethrow;
    }
    // Request audio focus and mark the audio session active where possible.
    try {
      if (_session != null) await _session!.setActive(true);
    } catch (e) {
      if (kDebugMode) debugPrint('AudioSession setActive(true) failed: $e');
    }
    // Best-effort: start the native keep-alive foreground service so the
    // notification/foreground process stays alive even if the Flutter
    // UI is destroyed or the app is swiped away.
    try {
      await _keepAliveChannel.invokeMethod('startService');
    } on MissingPluginException {
      // native implementation not available in some contexts; ignore
    } catch (e) {
      if (kDebugMode) debugPrint('keepAlive startService failed: $e');
    }
  }

  @override
  Future<void> pause() async {
    debugPrint('BackgroundAudioHandler: pause called');
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('BackgroundAudioHandler: pause error: $e');
      rethrow;
    }
    // Pause playback and release audio focus.
    try {
      if (_session != null) await _session!.setActive(false);
    } catch (e) {
      if (kDebugMode) debugPrint('AudioSession setActive(false) failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    debugPrint('BackgroundAudioHandler: stop called');
    _metadataTimer?.cancel();
    _metadataTimer = null;
    // Stop player and release audio focus.
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('BackgroundAudioHandler: stop error: $e');
    }
    try {
      if (_session != null) await _session!.setActive(false);
    } catch (e) {
      if (kDebugMode) debugPrint('AudioSession setActive(false) failed: $e');
    }
    // Best-effort: stop the native keep-alive foreground service so the
    // notification and native service are removed when playback stops.
    try {
      await _keepAliveChannel.invokeMethod('stopService');
    } on MissingPluginException {
      // ignore
    } catch (e) {
      if (kDebugMode) debugPrint('keepAlive stopService failed: $e');
    }
    debugPrint('BackgroundAudioHandler: stop completed');
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setUrl(String url, {Map<String, String>? extras}) async {
    debugPrint('BackgroundAudioHandler: setUrl called for $url');
    // prepare session
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // Prefer to cache artwork first so we can tag the AudioSource with a
    // local file:// URI. This improves notification artwork reliability when
    // the Flutter isolate is killed and `just_audio_background` needs a
    // local asset to display.
    try {
      final title = extras?['title'] ?? url;
      final artString = extras?['artUri'] ?? extras?['image'];
      Uri? artUri;
      if (artString != null && artString.isNotEmpty) {
        final parsed = Uri.tryParse(artString);
        if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
          try {
            final cached = await CacheHelper.cacheImage(parsed.toString());
            if (cached != null && cached.isNotEmpty) {
              artUri = Uri.file(cached);
            } else {
              artUri = parsed;
            }
          } catch (e) {
            artUri = parsed;
          }
        } else {
          artUri = parsed;
        }
      }

      final item = MediaItem(
        id: url,
        album: extras?['album'],
        title: title,
        artUri: artUri,
      );

      // Use AudioSource.uri with a tag so just_audio_background can show the
      // notification even if the Flutter engine is suspended. Tagging with
      // the `MediaItem` keeps audio metadata consistent between audio_service
      // and just_audio_background.
      final source = AudioSource.uri(Uri.parse(url), tag: item);
      await _player.setAudioSource(source);
      mediaItem.add(item);
      debugPrint('BackgroundAudioHandler: mediaItem added id=$url title=$title artUri=$artUri');
    } catch (e) {
      debugPrint('setUrl error: $e');
      // Fallback: try the simple setUrl if setAudioSource failed
      try {
        await _player.setUrl(url);
        final title = extras?['title'] ?? url;
        mediaItem.add(MediaItem(id: url, album: extras?['album'], title: title));
      } catch (e2) {
        debugPrint('setUrl fallback failed: $e2');
        rethrow;
      }
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
    // Append to internal queue so notification skip actions work even when
    // the app UI is not present. Keep the public API unchanged.
    _queue.add(mediaItem);
    // If nothing is currently loaded, make this the current item.
    if (_currentIndex == -1) {
      _currentIndex = 0;
      final first = _queue[_currentIndex];
      this.mediaItem.add(first);
      try {
        final source = AudioSource.uri(Uri.parse(first.id), tag: first);
        await _player.setAudioSource(source);
      } catch (e) {
        await _player.setUrl(first.id);
      }
    }
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('BackgroundAudioHandler: skipToNext');
    if (_queue.isNotEmpty && _currentIndex < _queue.length - 1) {
      _currentIndex++;
      final item = _queue[_currentIndex];
      this.mediaItem.add(item);
      try {
        final source = AudioSource.uri(Uri.parse(item.id), tag: item);
        await _player.setAudioSource(source);
      } catch (e) {
        await _player.setUrl(item.id);
      }
      await play();
      return;
    }
    // Fallback to app-level callback if queue navigation isn't available.
    try {
      AudioActions.onSkipNext?.call();
    } catch (e) {
      debugPrint('skipToNext callback failed: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('BackgroundAudioHandler: skipToPrevious');
    if (_queue.isNotEmpty && _currentIndex > 0) {
      _currentIndex--;
      final item = _queue[_currentIndex];
      this.mediaItem.add(item);
      try {
        final source = AudioSource.uri(Uri.parse(item.id), tag: item);
        await _player.setAudioSource(source);
      } catch (e) {
        await _player.setUrl(item.id);
      }
      await play();
      return;
    }
    // Fallback to app-level callback if queue navigation isn't available.
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
      androidNotificationIcon: 'ic_stat_bakwaas',
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
