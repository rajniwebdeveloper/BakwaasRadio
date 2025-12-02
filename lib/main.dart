import 'dart:math' as math;
import 'package:bakwaas_fm/api_service.dart';
import 'package:bakwaas_fm/models/station.dart';
import 'package:flutter/material.dart';
import 'library/song_page.dart';
import 'library/library_data.dart';
import 'playback_manager.dart';
import 'background_audio.dart';

import 'app_data.dart';
import 'profile_page.dart';
import 'library/playlist_detail_page.dart';
import 'library/liked_songs_page.dart';
import 'library/downloads_page.dart';
import 'widgets/bakwaas_chrome.dart';
import 'widgets/orbital_ring.dart';
import 'stations_page.dart';
import 'deep_link_handler.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
// ApiService already imported via package import at top

// Demo/sample songs removed. App will show live data or empty states.

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    return MaterialApp(
      navigatorKey: AppData.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Bakwaas FM',
      theme: base.copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: base.colorScheme.copyWith(
          primary: BakwaasPalette.neonGreen,
          secondary: BakwaasPalette.aqua,
          surface: BakwaasPalette.navy,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: const SplashPage(),
    );
  }

  // (moved helper to top-level so multiple widgets can use it)
}

/// A small splash page that initializes the app (loads persisted playback,
/// checks backend connectivity) and then navigates to `HomePage`.
int _compareVersions(String a, String b) {
  try {
    final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va > vb) return 1;
      if (va < vb) return -1;
    }
    return 0;
  } catch (_) {
    return 0;
  }
}
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _status = 'Starting...';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() => _status = 'Restoring playback...');
      await PlaybackManager.instance.loadPersisted();

      // Request notification permission early (Android 13+) so the
      // foreground service notification is allowed before starting playback.
      try {
        await requestNotificationPermission();
      } catch (_) {}

        // Eagerly initialize background audio handler so notifications
        // and the audio_service are ready before playback starts. This
        // improves the chance that the Android notification appears and
        // background playback works reliably when the user starts playback.
        try {
          await PlaybackManager.instance.ensureBackgroundHandler();
          // Start the native keep-alive foreground service so the
          // notification channel and native service are running prior
          // to any user-initiated playback. This helps ensure the
          // notification appears reliably when playback starts.
          try {
            await PlaybackManager.instance.startNativeKeepAlive();
          } catch (e) {
            debugPrint('Splash: startNativeKeepAlive failed: $e');
          }
        } catch (e) {
          debugPrint('Splash: ensureBackgroundHandler failed: $e');
        }


      // Fetch UI labels/config from backend (optional). Failures are non-fatal.
      try {
        final ui = await ApiService.getUiConfig();
        AppData.uiConfig.value = ui;
      } catch (e) {
        // ignore: avoid_print
        debugPrint('Splash: ui-config not available or failed: $e');
      }

      // Load lightweight app settings (preview autoplay toggle, etc.)
      try {
        await AppData.loadSettingsFromPrefs();
      } catch (_) {}

      // Restore persisted auth (if any) and validate token with /auth/me
      try {
        await AppData.loadAuthFromPrefs();
        if (AppData.isLoggedIn.value) {
          final token = AppData.currentUser.value['token'] as String?;
          if (token != null) {
            try {
              final me = await ApiService.me(token);
              if (me != null && me['ok'] == true) {
                final user = me['user'] as Map<String, dynamic>;
                AppData.currentUser.value = user;
                AppData.currentUser.value['token'] = token;
                AppData.isLoggedIn.value = true;
              } else {
                // invalid token -> clear
                AppData.currentUser.value = <String, dynamic>{};
                AppData.isLoggedIn.value = false;
                await AppData.clearAuthPrefs();
              }
            } catch (_) {
              // If validation fails, clear to avoid inconsistency
              AppData.currentUser.value = <String, dynamic>{};
              AppData.isLoggedIn.value = false;
              await AppData.clearAuthPrefs();
            }
          }
        }
      } catch (_) {}

      // Do NOT auto-play stations from the splash. Only check backend
      // reachability and fetch data. Playback restoration/resume should
      // be explicit (handled by player screen or user action).

      // Small delay so splash is visible briefly
      await Future.delayed(const Duration(milliseconds: 700));

      // Navigate to home. Update checks and station fetch will be
      // performed after HomePage loads to avoid blocking splash.
      if (!mounted) return;
      final nav = AppData.navigatorKey.currentState;
      if (nav != null) {
        nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } catch (e) {
      // On unexpected failure, still proceed but show message briefly
      setState(() => _status = 'Initialization failed — continuing');
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      final nav = AppData.navigatorKey.currentState;
      if (nav != null) {
        nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
    }

  }

  // version compare helper removed; update-check moved to HomePage
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fullscreen logo background
          Positioned.fill(
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
            ),
          ),
          // Semi-transparent overlay for readable text
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.45)),
          ),
          // Centered app name and status/progress
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Bakwaas FM',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                const CircularProgressIndicator(color: BakwaasPalette.neonGreen),
                const SizedBox(height: 10),
                Text(_status, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
  with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final PlaybackManager _playback = PlaybackManager.instance;
  late final AnimationController _ringController;
  int _activeTab = 0;
  bool _previewStarted = false;
  // Navigation now uses inline tabs; no nav lock required.

  @override
  void initState() {
    super.initState();
    _ringController =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat();
    _playback.addListener(_handlePlayback);
    // Ensure library live data is loaded so UI can react in real-time.
    LibraryData.load();
    // Initialize active tab from global state so initial rendering matches
    // any previous tab requests (prevents first-frame mismatch).
    _activeTab = AppData.rootTab.value.clamp(0, 2);
    // Listen for global tab changes requested by other pages
    AppData.rootTab.addListener(() {
      if (!mounted) return;
      setState(() => _activeTab = AppData.rootTab.value.clamp(0, 2));
    });
    // Register lifecycle observer to pause playback when app backgrounded
    WidgetsBinding.instance.addObserver(this);
    // Load persisted playback state but do NOT auto-resume playback here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PlaybackManager.instance.loadPersisted().then((_) async {
        debugPrint('Home: loadPersisted completed (no auto-resume)');
        // After the UI is visible, check for app updates then load stations
        await _checkUpdateThenLoadStations();
      });
    });
    // Start a one-time listener to autoplay a short preview when stations finish loading
    LibraryData.stations.addListener(_onStationsLoaded);
    // Start listening for deep links and share intents (incoming URLs)
    DeepLinkHandler.instance.startListening();
  }

  /// Run update check first (on Home), then fetch stations.
  Future<void> _checkUpdateThenLoadStations() async {
    try {
      debugPrint('Home: checking update info');
      final nowTs = DateTime.now().toUtc().toIso8601String();
      final info = await ApiService.getUpdateInfo(v: AppInfo.version, ts: nowTs);
      if (info != null && info is Map<String, dynamic>) {
        String key;
        if (kIsWeb) {
          key = 'web';
        } else if (io.Platform.isIOS) {
          key = 'iso';
        } else if (io.Platform.isAndroid) {
          key = 'android';
        } else if (io.Platform.isMacOS) {
          key = 'macos';
        } else if (io.Platform.isWindows) {
          key = 'windows';
        } else {
          key = 'web';
        }
        final platformInfo = info[key];
        if (platformInfo is Map<String, dynamic>) {
          final serverVersion = (platformInfo['version'] ?? '') as String;
          final serverBuild = (platformInfo['build'] ?? platformInfo['code']);
          bool shouldShow = false;
          if (serverVersion.isNotEmpty) {
            if (_compareVersions(serverVersion, AppInfo.version) > 0) shouldShow = true;
          }
          if (!shouldShow && serverBuild != null) {
            try {
              final int serverBuildInt = int.parse(serverBuild.toString());
              if (serverBuildInt > AppInfo.buildNumber) shouldShow = true;
            } catch (_) {}
          }
          if (shouldShow && mounted) {
            final releaseNotes = (platformInfo['releaseNotes'] ?? '') as String;
            final url = (platformInfo['url'] ?? '') as String;
            final force = (platformInfo['force'] ?? false) as bool;
            var urlValid = false;
            if (url.isNotEmpty) {
              final uri = Uri.tryParse(url);
              if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
                try {
                  final head = await http.head(uri).timeout(const Duration(seconds: 2));
                  if (head.statusCode >= 200 && head.statusCode < 400) urlValid = true;
                } catch (e) {
                  debugPrint('Home: failed to verify update URL: $e');
                  urlValid = false;
                }
              } else {
                urlValid = true;
              }
            }
            if (!urlValid) {
              debugPrint('Home: Ignoring update because update URL is missing or unreachable');
            } else {
              // Show dialog; if user selects Close we exit the app.
              // ignore: use_build_context_synchronously
              await showDialog<void>(
                context: context,
                barrierDismissible: !force,
                builder: (ctx) {
                  return WillPopScope(
                    onWillPop: () async => !force,
                    child: AlertDialog(
                      title: const Text('Update Available'),
                      content: SingleChildScrollView(child: Text(releaseNotes.isNotEmpty ? releaseNotes : 'A new version is available.')),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await Future.delayed(const Duration(milliseconds: 200));
                            try {
                              SystemNavigator.pop();
                            } catch (_) {
                              io.exit(0);
                            }
                          },
                          child: const Text('Close'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            if (url.isNotEmpty) {
                              try {
                                await launchUrlString(url);
                              } catch (_) {}
                            }
                          },
                          child: const Text('Update Now'),
                        ),
                      ],
                    ),
                  );
                },
              );
              if (!mounted) return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Home: update check failed or timed out: $e');
    }

    // Now fetch stations (non-blocking failures are OK)
    try {
      await LibraryData.load();
      debugPrint('Home: stations loaded: ${LibraryData.stations.value.length}');
    } catch (e) {
      debugPrint('Home: failed to load stations: $e');
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    _playback.removeListener(_handlePlayback);
    WidgetsBinding.instance.removeObserver(this);
    LibraryData.stations.removeListener(_onStationsLoaded);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app is backgrounded or the screen locks, pause playback.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      try {
        PlaybackManager.instance.pause();
      } catch (_) {}
    }
  }

  void _onStationsLoaded() {
    _startPreviewIfNeeded();
  }

  Future<void> _startPreviewIfNeeded() async {
    if (_previewStarted) return;
    final stations = LibraryData.stations.value;
    if (stations.isEmpty) return;
    Station? chosen;
    for (final s in stations) {
      final url = s.playerUrl ?? s.streamURL ?? s.mp3Url ?? '';
      if (url.isNotEmpty) {
        chosen = s;
        break;
      }
    }
    if (chosen == null) return;
    if (PlaybackManager.instance.isPlaying) return;
    // Respect user setting: only autoplay preview when enabled
    if (!AppData.enablePreviewAutoplay.value) return;
    final Station s = chosen;
    _previewStarted = true;
    final song = {
      'title': s.name,
      'subtitle': s.description ?? '',
      'image': s.profilepic ?? '',
      'url': s.playerUrl ?? s.streamURL ?? s.mp3Url ?? ''
    };
    try {
      await PlaybackManager.instance.play(song, duration: 10);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SongPage(
              station: s,
              title: s.name,
              subtitle: s.description ?? '',
              imageUrl: s.profilepic,
                                      autoplay: false,
                                      showBottomNav: false,
            )));
  }

  void _handlePlayback() => setState(() {});

  Map<String, String>? get _heroSong =>
      _playback.currentSong ?? _playback.lastSong;

  // helper removed: open full player now uses explicit navigation where needed

  Future<void> _playPrevious() async {
    final history = PlaybackManager.instance.history;
    if (history.length >= 2) {
      // history[0] is current, history[1] is previous
      final prev = history[1];
      final ok = await PlaybackManager.instance.play(prev);
      if (ok && mounted) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SongPage(
                  title: prev['title'] ?? '',
                  subtitle: prev['subtitle'] ?? '',
                  imageUrl: prev['image'],
                  autoplay: true,
                                showBottomNav: false,
                )));
      }
      return;
    }
    // Fallback: pick a random station
    final stations = LibraryData.stations.value;
    if (stations.isNotEmpty) {
      final s = stations[math.Random().nextInt(stations.length)];
      final url = s.playerUrl ?? s.streamURL ?? s.mp3Url ?? '';
      if (url.isNotEmpty) {
        final song = {
          'title': s.name,
          'subtitle': s.description ?? '',
          'image': s.profilepic ?? '',
          'url': url
        };
        final ok = await PlaybackManager.instance.play(song);
        if (ok && mounted) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SongPage(
                    title: song['title'] ?? '',
                    subtitle: song['subtitle'] ?? '',
                    imageUrl: song['image'],
                    autoplay: true,
                    showBottomNav: false,
                  )));
        }
      }
    }
  }

  Future<void> _playNext() async {
    final stations = LibraryData.stations.value;
    final currentUrl = PlaybackManager.instance.currentSong?['url'] ?? PlaybackManager.instance.lastSong?['url'];
    if (stations.isNotEmpty) {
      // try to find station matching currentUrl
      int found = -1;
      for (var i = 0; i < stations.length; i++) {
        final s = stations[i];
        final candidates = <String?>[s.playerUrl, s.streamURL, s.mp3Url];
        for (final c in candidates) {
          if (c == null || currentUrl == null) continue;
          if (c.trim() == currentUrl.trim() || c.contains(currentUrl) || currentUrl.contains(c)) {
            found = i;
            break;
          }
        }
        if (found != -1) break;
      }
      Station? nextStation;
      if (found != -1) {
        nextStation = stations[(found + 1) % stations.length];
      } else {
        // pick a random station
        nextStation = stations[math.Random().nextInt(stations.length)];
      }
      final url = nextStation.playerUrl ?? nextStation.streamURL ?? nextStation.mp3Url ?? '';
      if (url.isNotEmpty) {
        final song = {
          'title': nextStation.name,
          'subtitle': nextStation.description ?? '',
          'image': nextStation.profilepic ?? '',
          'url': url
        };
        final ok = await PlaybackManager.instance.play(song);
        if (ok && mounted) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SongPage(
                    title: song['title'] ?? '',
                    subtitle: song['subtitle'] ?? '',
                    imageUrl: song['image'],
                    autoplay: true,
                    showBottomNav: false,
                  )));
        }
      }
      return;
    }
    // fallback: nothing to do
  }

  @override
  Widget build(BuildContext context) {
    // Avoid demo defaults; show live data only when available.
    final heroSong = _heroSong ?? <String, String>{};
    final cover = heroSong['image'];

    return BakwaasScaffold(
      backgroundImage: cover,
      activeTab: _activeTab,
      onMenuTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) {
            return SafeArea(
              child: ValueListenableBuilder<Map<String, dynamic>>(
                valueListenable: AppData.uiConfig,
                builder: (ctx, ui, __) {
                  String lab(String key, String fallback) {
                    final labels = ui['labels'] as Map<String, dynamic>?;
                    return (labels != null && labels.containsKey(key)) ? (labels[key] as String) : fallback;
                  }

                  final enableDownloads = (ui['features'] is Map<String, dynamic>)
                      ? ((ui['features'] as Map<String, dynamic>)['enable_downloads'] as bool? ?? false)
                      : false;

                  return Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12))),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person, color: Colors.white),
                          title: Text(lab('menu_profile', 'Profile'),
                              style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const ProfilePage()));
                          },
                        ),
                        // Downloads menu should be visible only when backend
                        // feature flag is enabled AND user is logged in.
                        ValueListenableBuilder<bool>(
                          valueListenable: AppData.isLoggedIn,
                          builder: (ctx2, loggedIn, __) {
                            if (enableDownloads && loggedIn) {
                              return ListTile(
                                leading: const Icon(Icons.download, color: Colors.white),
                                title: Text(lab('menu_downloads', 'Downloads'), style: const TextStyle(color: Colors.white)),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DownloadsPage()));
                                },
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.filter_list, color: Colors.white),
                          title: Text(lab('menu_filters', 'Filters'),
                              style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.of(context).pop();
                            showModalBottomSheet<void>(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (_) {
                                  return SafeArea(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(12),
                                              topRight: Radius.circular(12))),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(lab('filters_title', 'Library Filters'),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 12),
                                          ValueListenableBuilder<Set<String>>(
                                              valueListenable: LibraryData.filters,
                                              builder: (ctx, active, __) {
                                                bool has(String k) => active.contains(k);
                                                return Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    CheckboxListTile(
                                                      value: has('liked'),
                                                      onChanged: (v) {
                                                        final s = Set<String>.from(LibraryData.filters.value);
                                                        if (v == true) {
                                                          s.add('liked');
                                                        } else {
                                                          s.remove('liked');
                                                        }
                                                        LibraryData.filters.value = s;
                                                      },
                                                      title: Text(lab('filter_liked', 'Liked Songs'), style: const TextStyle(color: Colors.white)),
                                                      activeColor: BakwaasPalette.neonGreen,
                                                      controlAffinity: ListTileControlAffinity.leading,
                                                    ),
                                                    CheckboxListTile(
                                                      value: has('albums'),
                                                      onChanged: (v) {
                                                        final s = Set<String>.from(LibraryData.filters.value);
                                                        if (v == true) {
                                                          s.add('albums');
                                                        } else {
                                                          s.remove('albums');
                                                        }
                                                        LibraryData.filters.value = s;
                                                      },
                                                      title: Text(lab('filter_albums', 'Albums'), style: const TextStyle(color: Colors.white)),
                                                      activeColor: BakwaasPalette.neonGreen,
                                                      controlAffinity: ListTileControlAffinity.leading,
                                                    ),
                                                    CheckboxListTile(
                                                      value: has('artists'),
                                                      onChanged: (v) {
                                                        final s = Set<String>.from(LibraryData.filters.value);
                                                        if (v == true) {
                                                          s.add('artists');
                                                        } else {
                                                          s.remove('artists');
                                                        }
                                                        LibraryData.filters.value = s;
                                                      },
                                                      title: Text(lab('filter_artists', 'Artists'), style: const TextStyle(color: Colors.white)),
                                                      activeColor: BakwaasPalette.neonGreen,
                                                      controlAffinity: ListTileControlAffinity.leading,
                                                    ),
                                                      // Show the Downloads filter only when the backend
                                                      // feature flag is enabled AND the user is logged in.
                                                      // This prevents the UI from advertising download
                                                      // functionality when it's not available.
                                                        if (enableDownloads)
                                                        ValueListenableBuilder<bool>(
                                                          valueListenable: AppData.isLoggedIn,
                                                          builder: (ctx3, loggedIn, __) {
                                                            if (!loggedIn) return const SizedBox.shrink();
                                                            return CheckboxListTile(
                                                              value: has('downloads'),
                                                              onChanged: (v) {
                                                                final s = Set<String>.from(LibraryData.filters.value);
                                                                if (v == true) {
                                                                  s.add('downloads');
                                                                } else {
                                                                  s.remove('downloads');
                                                                }
                                                                LibraryData.filters.value = s;
                                                              },
                                                              title: Text(lab('filter_downloads', 'Downloads'), style: const TextStyle(color: Colors.white)),
                                                              activeColor: BakwaasPalette.neonGreen,
                                                              controlAffinity: ListTileControlAffinity.leading,
                                                            );
                                                          },
                                                        ),
                                                    CheckboxListTile(
                                                      value: has('playlists'),
                                                      onChanged: (v) {
                                                        final s = Set<String>.from(LibraryData.filters.value);
                                                        if (v == true) {
                                                          s.add('playlists');
                                                        } else {
                                                          s.remove('playlists');
                                                        }
                                                        LibraryData.filters.value = s;
                                                      },
                                                      title: Text(lab('filter_playlists', 'Playlists'), style: const TextStyle(color: Colors.white)),
                                                      activeColor: BakwaasPalette.neonGreen,
                                                      controlAffinity: ListTileControlAffinity.leading,
                                                    ),
                                                    CheckboxListTile(
                                                      value: has('stations'),
                                                      onChanged: (v) {
                                                        final s = Set<String>.from(LibraryData.filters.value);
                                                        if (v == true) {
                                                          s.add('stations');
                                                        } else {
                                                          s.remove('stations');
                                                        }
                                                        LibraryData.filters.value = s;
                                                      },
                                                      title: Text(lab('filter_stations', 'Stations'), style: const TextStyle(color: Colors.white)),
                                                      activeColor: BakwaasPalette.neonGreen,
                                                      controlAffinity: ListTileControlAffinity.leading,
                                                    ),
                                                    CheckboxListTile(
                                                      value: has('recent'),
                                                      onChanged: (v) {
                                                        final s = Set<String>.from(LibraryData.filters.value);
                                                        if (v == true) {
                                                          s.add('recent');
                                                        } else {
                                                          s.remove('recent');
                                                        }
                                                        LibraryData.filters.value = s;
                                                      },
                                                      title: Text(lab('filter_recent', 'Recently Played'), style: const TextStyle(color: Colors.white)),
                                                      activeColor: BakwaasPalette.neonGreen,
                                                      controlAffinity: ListTileControlAffinity.leading,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        TextButton(
                                                            onPressed: () {
                                                              LibraryData.filters.value = <String>{};
                                                              Navigator.of(ctx).pop();
                                                            },
                                                            child: Text(lab('filters_clear', 'Clear'), style: const TextStyle(color: Colors.white70))),
                                                        const SizedBox(width: 8),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: BakwaasPalette.neonGreen),
                                                          onPressed: () => Navigator.of(ctx).pop(),
                                                          child: Text(lab('filters_done', 'Done')),
                                                        )
                                                      ],
                                                    )
                                                  ],
                                                );
                                              }),
                                        ],
                                      ),
                                    ),
                                  );
                                });
                          },
                        ),
                        // Toggle: preview autoplay when stations load
                        ValueListenableBuilder<bool>(
                          valueListenable: AppData.enablePreviewAutoplay,
                          builder: (ctx4, enabled, __) {
                            return SwitchListTile(
                              secondary: const Icon(Icons.play_arrow, color: Colors.white),
                              title: const Text('Auto Preview', style: TextStyle(color: Colors.white)),
                              value: enabled,
                              onChanged: (v) async {
                                await AppData.saveEnablePreviewAutoplay(v);
                                setState(() {});
                              },
                              activeThumbColor: BakwaasPalette.neonGreen,
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.play_circle_fill, color: Colors.white),
                          title: Text(lab('menu_now_playing', 'Now Playing'), style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.of(context).pop();
                            final song = _heroSong ?? {'title': 'Dhaka FM', 'subtitle': 'Live Radio', 'image': ''};
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => SongPage(
                                      title: song['title'] ?? 'Dhaka FM',
                                      subtitle: song['subtitle'] ?? 'Live Radio',
                                      imageUrl: song['image'],
                                      autoplay: _playback.isPlaying,
                                    )));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.timer, color: Colors.white),
                          title: Text(lab('menu_sleep_timer', 'Sleep Timer'), style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.of(context).pop();
                            showModalBottomSheet<void>(
                                context: context,
                                builder: (_) {
                                  return SafeArea(
                                      child: Container(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                                      const Text('Set Sleep Timer', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      ListTile(title: const Text('15 minutes'), onTap: () => Navigator.of(context).pop()),
                                      ListTile(title: const Text('30 minutes'), onTap: () => Navigator.of(context).pop()),
                                      ListTile(title: const Text('60 minutes'), onTap: () => Navigator.of(context).pop()),
                                    ]),
                                  ));
                                });
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  );
                },
              ),
            );
          }),
      onExitTap: () {
        // Removed direct navigation to ProfilePage from the top-right icon.
        // Previously this opened the profile; keep as a no-op now.
      },
      bodyPadding: EdgeInsets.zero,
      body: _activeTab == 0
          ? const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: StationsPage(useScaffold: false),
            )
          : (_activeTab == 1)
              ? ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    _buildHeroSection(heroSong),
                    const SizedBox(height: 18),
                    // Quick access to Stations (kept for consistency)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const StationsPage())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration:
                            BakwaasTheme.glassDecoration(radius: 22, opacity: 0.06),
                        child: const Row(
                          children: [
                            Icon(Icons.radio, color: Colors.white70),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text('Browse Stations',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700))),
                            Icon(Icons.chevron_right, color: Colors.white70)
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                )
              : (_activeTab == 2)
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: LikedSongsContent(),
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: const [
                        // fallback: show stations if unknown
                        Padding(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: StationsPage(useScaffold: false),
                        ),
                      ],
                    ),
      onNavTap: (index) {
        // Use inline tabs for all primary sections so the bottom nav stays
        // visible and Home is the default.
        final idx = index.clamp(0, 2);
        setState(() => _activeTab = idx);
        // Keep global tab state in sync so other widgets/pages can request
        // tab switches through `AppData.rootTab` as well.
        AppData.rootTab.value = idx;
      },
    );
  }

  Widget _buildHeroSection(Map<String, String> song) {
    return Column(
      children: [
        _buildOrbit(song['image']),
        const SizedBox(height: 18),
        _buildNowPlayingCard(song),
        const SizedBox(height: 18),
        _buildControls(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOrbit(String? imageUrl) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double size = (screenWidth * 0.45).clamp(140.0, 260.0);
    return SizedBox(
      width: size + 48,
      height: size + 48,
      child: AnimatedBuilder(
        animation: _ringController,
        builder: (context, _) {
          final rotation =
              _playback.isPlaying ? _ringController.value * 2 * math.pi : 0.0;
          return CustomPaint(
            painter: OrbitalRingPainter(
              tick: _ringController.value,
              color: BakwaasPalette.aqua,
              intensity: _playback.isPlaying ? 1.0 : 0.35,
            ),
            child: Center(
              child: Transform.rotate(
                angle: rotation,
                child: Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [Color(0xFF1F1F2C), Color(0xFF151521)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: imageUrl != null && imageUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : const DecorationImage(
                              image: AssetImage('assets/logo.png'),
                              fit: BoxFit.cover,
                            ),
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNowPlayingCard(Map<String, String> song) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BakwaasTheme.glassDecoration(radius: 32, opacity: 0.12),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('♪',
                  style: TextStyle(color: BakwaasPalette.aqua, fontSize: 14)),
              SizedBox(width: 6),
              Text('NOW PLAYING',
                  style: TextStyle(
                      color: Colors.white70,
                      letterSpacing: 2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              SizedBox(width: 6),
              Text('♪',
                  style: TextStyle(color: BakwaasPalette.aqua, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(song['title'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
              Text(song['subtitle'] ?? '',
              textAlign: TextAlign.center,
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withAlpha((0.78 * 255).round()))),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: Colors.white.withAlpha((0.05 * 255).round())),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            onPressed: _playPrevious,
            icon: const Icon(Icons.skip_previous, color: Colors.white70),
            iconSize: 32,
          ),
          GestureDetector(
            onTap: _playback.toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: BakwaasTheme.glowGradient,
                boxShadow: [
                  BoxShadow(
                    color: BakwaasPalette.neonGreen
                        .withAlpha(((_playback.isPlaying ? 0.45 : 0.2) * 255).round()),
                    blurRadius: _playback.isPlaying ? 28 : 16,
                    spreadRadius: _playback.isPlaying ? 6 : 2,
                  ),
                ],
              ),
              child: _playback.isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.6,
                        ),
                      ),
                    )
                  : Icon(
                      _playback.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 38,
                    ),
            ),
          ),
          IconButton(
            onPressed: _playNext,
            icon: const Icon(Icons.skip_next, color: Colors.white70),
            iconSize: 32,
          ),
        ],
      ),
    );
  }

  // Widget _buildProgress() {
  //   final progress = _playback.progress.clamp(0.0, 1.0);
  //   return Column(
  //     children: [
  //       SliderTheme(
  //         data: SliderTheme.of(context).copyWith(
  //           trackHeight: 4,
  //           activeTrackColor: BakwaasPalette.neonGreen,
  //           inactiveTrackColor: Colors.white.withOpacity(0.15),
  //           thumbColor: Colors.white,
  //           overlayColor: BakwaasPalette.neonGreen.withOpacity(0.15),
  //           thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
  //         ),
  //         child: Slider(
  //           value: progress,
  //           onChanged:
  //               _playback.currentSong != null ? (v) => _playback.seek(v) : null,
  //         ),
  //       ),
  //       const SizedBox(height: 4),
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           Text(_playback.isPlaying ? 'Now Playing…' : "Let's Play…",
  //               style: TextStyle(color: Colors.white.withOpacity(0.72))),
  //           Text(_formatTime(progress * _playback.durationSeconds),
  //               style: TextStyle(color: Colors.white.withOpacity(0.72))),
  //         ],
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildVolumeAndBanner(Map<String, String> song) {
  //   final volume = _playback.volume;
  //   return Column(
  //     children: [
  //       GestureDetector(
  //         onPanUpdate: (details) {
  //           final updated =
  //               (_playback.volume - details.delta.dy / 300).clamp(0.0, 1.0);
  //           _playback.setVolume(updated);
  //         },
  //         child: Column(
  //           children: [
  //             Stack(
  //               alignment: Alignment.center,
  //               children: [
  //                 Container(
  //                   width: 96 + (volume * 18),
  //                   height: 96 + (volume * 18),
  //                   decoration: BoxDecoration(
  //                     shape: BoxShape.circle,
  //                     color: Colors.transparent,
  //                     boxShadow: [
  //                       BoxShadow(
  //                         color: BakwaasPalette.neonGreen
  //                             .withOpacity(0.15 + volume * 0.25),
  //                         blurRadius: 26 + volume * 18,
  //                         spreadRadius: 7 + volume * 5,
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //                 Container(
  //                   width: 98,
  //                   height: 98,
  //                   decoration: BoxDecoration(
  //                     shape: BoxShape.circle,
  //                     gradient: BakwaasTheme.glowGradient,
  //                     boxShadow: [
  //                       BoxShadow(
  //                         color: BakwaasPalette.neonGreen
  //                             .withOpacity(0.25 + volume * 0.25),
  //                         blurRadius: 18 + volume * 12,
  //                         spreadRadius: 2 + volume * 3,
  //                       ),
  //                     ],
  //                   ),
  //                   child: const SizedBox.shrink(),
  //                 ),
  //               ],
  //             ),
  //             const SizedBox(height: 12),
  //             SliderTheme(
  //               data: SliderTheme.of(context).copyWith(
  //                 trackHeight: 3,
  //                 activeTrackColor: Colors.white,
  //                 inactiveTrackColor: Colors.white.withOpacity(0.2),
  //                 thumbColor: Colors.white,
  //                 overlayColor: Colors.white.withOpacity(0.12),
  //               ),
  //               child: Slider(
  //                 value: volume,
  //                 onChanged: (v) => _playback.setVolume(v),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       const SizedBox(height: 12),
  //       _buildLetsPlayBanner(song),
  //     ],
  //   );
  // }

  // (Removed unused helper banner and format functions)
}

class TabsRow extends StatelessWidget {
  const TabsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          ToggleButton(label: 'Music', selected: true),
          SizedBox(width: 10),
          ToggleButton(label: 'Shows', selected: false),
          SizedBox(width: 10),
          ToggleButton(label: 'Live', selected: false),
        ],
      ),
    );
  }
}

class ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  const ToggleButton({super.key, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withAlpha((0.08 * 255).round())
            : Colors.white.withAlpha((0.02 * 255).round()),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withAlpha(((selected ? 0.3 : 0.12) * 255).round())),
      ),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              fontSize: 12)),
    );
  }
}

enum CardType { album, playlist, station }

class Section extends StatelessWidget {
  final String title;
  final int itemCount;
  final CardType cardType;
  final VoidCallback? onViewAll;
  const Section(
      {super.key,
      required this.title,
      required this.itemCount,
      required this.cardType,
      this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onViewAll: onViewAll),
        const SizedBox(height: 12),
        SizedBox(
          height: cardType == CardType.station ? 220 : 190,
          child: cardType == CardType.station
              ? ValueListenableBuilder<List<Station>>(
                  valueListenable: LibraryData.stations,
                  builder: (context, stations, __) {
                    if (stations.isNotEmpty) {
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: stations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final station = stations[index];
                          return SizedBox(
                            width: 150,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(26),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => SongPage(
                                        station: station,
                                        title: station.name,
                                        subtitle: station.description ?? '',
                                        imageUrl: station.profilepic,
                                        autoplay: true)));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BakwaasTheme.glassDecoration(
                                    radius: 26, opacity: 0.1),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(22),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            image: (station.profilepic !=
                                                        null &&
                                                    station
                                                        .profilepic!.isNotEmpty)
                                                ? DecorationImage(
                                                    image: NetworkImage(
                                                        station.profilepic!),
                                                    fit: BoxFit.cover)
                                                : null,
                                            color:
                                              Colors.white.withAlpha((0.05 * 255).round()),
                                          ),
                                          child: (station.profilepic == null ||
                                                  station.profilepic!.isEmpty)
                                              ? const Center(
                                                  child: Icon(Icons.radio,
                                                      size: 38,
                                                      color: Colors.white70))
                                              : null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(station.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(station.description ?? 'Live station',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color:
                                            Colors.white.withAlpha((0.7 * 255).round()),
                                          fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                    // Show loader while empty (attempting to fetch)
                    return const Center(
                        child: CircularProgressIndicator(
                            color: BakwaasPalette.neonGreen));
                  },
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    if (cardType == CardType.album) {
                      final title = 'Item ${index + 1}';
                      return SizedBox(
                        width: 140,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => SongPage(
                                    title: title,
                                    subtitle: '',
                                    imageUrl: null,
                                    autoplay: false)));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BakwaasTheme.glassDecoration(
                                radius: 24, opacity: 0.08),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF3D1E5A),
                                            Color(0xFF152445)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight),
                                    ),
                                    child: const Center(
                                        child: Icon(Icons.album,
                                            size: 32, color: Colors.white70)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                Text('Personal mix',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha((0.6 * 255).round()),
                                    fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      );
                    } else {
                      // Handle empty playlists gracefully
                      if (AppData.playlists.isEmpty) {
                        return SizedBox(
                          width: 150,
                            child: Center(
                            child: Text('No playlists yet',
                              style: TextStyle(
                                color: Colors.white.withAlpha((0.6 * 255).round())))),
                        );
                      }
                      final playlist =
                          AppData.playlists[index % AppData.playlists.length];
                      final title = playlist['title'] ?? '';
                      final imageUrl = playlist['image'];
                      return SizedBox(
                        width: 150,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      PlaylistDetailPage(playlist: playlist))),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BakwaasTheme.glassDecoration(
                                radius: 24, opacity: 0.1),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      image: (imageUrl != null &&
                                              (imageUrl as String).isNotEmpty)
                                          ? DecorationImage(
                                              image: NetworkImage(imageUrl),
                                              fit: BoxFit.cover)
                                          : null,
                                      gradient: imageUrl == null ||
                                              (imageUrl as String).isEmpty
                                          ? const LinearGradient(
                                              colors: [
                                                  Color(0xFF2E6E60),
                                                  Color(0xFF2A1B47)
                                                ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight)
                                          : null,
                                    ),
                                    child: (imageUrl == null ||
                                            (imageUrl as String).isEmpty)
                                        ? const Center(
                                            child: Icon(Icons.playlist_play,
                                                size: 32,
                                                color: Colors.white70))
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                Text('Tap to explore',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha((0.65 * 255).round()),
                                    fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  const SectionHeader({super.key, required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        TextButton(
          onPressed: onViewAll ?? () {},
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('VIEW ALL',
                  style: TextStyle(
                      color: BakwaasPalette.aqua,
                      fontSize: 12,
                      letterSpacing: 1)),
              SizedBox(width: 2),
              Icon(Icons.chevron_right, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

// Page to show songs in a vertical list
class AllSongsPage extends StatelessWidget {
  final String title;
  final List<Map<String, String>> songs;
  const AllSongsPage({super.key, required this.title, required this.songs});

  @override
  Widget build(BuildContext context) {
    final cover = songs.isNotEmpty ? songs.first['image'] : null;
    return BakwaasScaffold(
      backgroundImage: cover,
      activeTab: 0,
      showBottomNav: false,
      onMenuTap: () => Navigator.of(context).maybePop(),
      onExitTap: () => Navigator.of(context).maybePop(),
      bodyPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: songs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final s = songs[idx];
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SongPage(
                          title: s['title'] ?? '',
                          subtitle: s['subtitle'] ?? '',
                          imageUrl: s['image']))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration:
                        BakwaasTheme.glassDecoration(radius: 18, opacity: 0.08),
                    child: Row(
                      children: [
                        CircleAvatar(
                            radius: 28,
                            backgroundImage:
                                s['image'] != null && s['image']!.isNotEmpty
                                    ? NetworkImage(s['image']!)
                                    : const AssetImage('assets/logo.png')
                                        as ImageProvider,
                            backgroundColor: Colors.white.withAlpha((0.08 * 255).round())),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['title'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(s['subtitle'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha((0.7 * 255).round()),
                                    fontSize: 11)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Colors.white70, size: 20)
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Trending grid page with 3 columns
class TrendingGridPage extends StatelessWidget {
  final List<Map<String, String>> songs;
  const TrendingGridPage({super.key, required this.songs});

  @override
  Widget build(BuildContext context) {
    final cover = songs.isNotEmpty ? songs.first['image'] : null;
    return BakwaasScaffold(
      backgroundImage: cover,
      activeTab: 2,
      showBottomNav: false,
      onMenuTap: () => Navigator.of(context).maybePop(),
      onExitTap: () => Navigator.of(context).maybePop(),
      bodyPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trending Now',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 18),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.82,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14),
              itemCount: songs.length,
              itemBuilder: (context, i) {
                final s = songs[i % songs.length];
                return InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SongPage(
                          title: s['title'] ?? '',
                          subtitle: s['subtitle'] ?? '',
                          imageUrl: s['image'],
                          autoplay: true))),
                  child: Container(
                    decoration:
                        BakwaasTheme.glassDecoration(radius: 22, opacity: 0.08),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(22)),
                            child: Container(
                              decoration: BoxDecoration(
                                image: s['image'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(s['image']!),
                                        fit: BoxFit.cover)
                                    : null,
                                color: Colors.white.withAlpha((0.04 * 255).round()),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(s['title'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
