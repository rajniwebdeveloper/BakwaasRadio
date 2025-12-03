import 'dart:math' as math;
import 'package:bakwaas_fm/models/station.dart';
import 'package:flutter/material.dart';
import '../playback_manager.dart';
import '../app_data.dart';
import 'liked_songs_manager.dart';
import '../widgets/bakwaas_chrome.dart';
import '../widgets/orbital_ring.dart';
import 'package:flutter/services.dart';

class SystemVolumeControl extends StatefulWidget {
  const SystemVolumeControl({super.key});
  @override
  State<SystemVolumeControl> createState() => _SystemVolumeControlState();
}

class _SystemVolumeControlState extends State<SystemVolumeControl> {
  static const MethodChannel _volumeChannel = MethodChannel('com.bakwaas.fm/volume');
  double _vol = 0.5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cur = await _volumeChannel.invokeMethod('getVolume');
      setState(() {
        _vol = (cur is double) ? cur : (cur is num ? cur.toDouble() : 0.5);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.mic, color: Colors.white70),
        const SizedBox(width: 12),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withAlpha((0.18 * 255).round()),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: _vol.clamp(0.0, 1.0),
              onChanged: (v) async {
                setState(() => _vol = v);
                try {
                  await _volumeChannel.invokeMethod('setVolume', v);
                } catch (_) {}
              },
            ),
          ),
        ),
      ],
    );
  }
}

class SongPage extends StatefulWidget {
  final Station? station;
  final String title;
  final String subtitle;
  final String? imageUrl; // optional image to show inside the CD
  final bool autoplay; // whether to auto-start playback when opened
    final bool showBottomNav;
    const SongPage(
      {super.key,
      this.station,
      required this.title,
      required this.subtitle,
      this.imageUrl,
      this.autoplay = false,
      this.showBottomNav = false});

  @override
  State<SongPage> createState() => _SongPageState();
}

class _SongPageState extends State<SongPage> with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _ringController;
  bool _isPlaying = false;
  double _progress = 0.0;
  int _durationSeconds = 0;

  // Songs list starts empty; we'll populate from `station` or passed title only.
  final List<Map<String, String>> _songs = [];

  int _currentIndex = 0;
  static const int _totalSeconds = 3 * 60 + 11; // 3:11

  @override
  void initState() {
    super.initState();
    _rotationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10));
    _ringController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();



    // listen to global playback manager
    PlaybackManager.instance.addListener(_playbackListener);

    if (widget.station != null) {
      _songs.insert(0, {
        'title': widget.station!.name,
        'subtitle': widget.station!.description ?? '',
        'image': widget.station!.profilepic ?? '',
        'url': widget.station!.playerUrl ?? ''
      });
      _currentIndex = 0;
      if (widget.autoplay) {
        PlaybackManager.instance.play({
          'title': widget.station!.name,
          'subtitle': widget.station!.description ?? '',
          'image': widget.station!.profilepic ?? '',
          'url': widget.station!.playerUrl ?? ''
        }, duration: _totalSeconds);
      }
    } else if (widget.title.isNotEmpty) {
      _songs.insert(0, {
        'title': widget.title,
        'subtitle': widget.subtitle,
        'image': widget.imageUrl ?? ''
      });
      _currentIndex = 0;
      if (widget.autoplay) {
        PlaybackManager.instance.play({
          'title': widget.title,
          'subtitle': widget.subtitle,
          'image': widget.imageUrl ?? ''
        }, duration: _totalSeconds);
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _ringController.dispose();
    PlaybackManager.instance.removeListener(_playbackListener);
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _togglePlay() {
    if (PlaybackManager.instance.isPlaying) {
      PlaybackManager.instance.pause();
    } else {
      final current = PlaybackManager.instance.currentSong ??
          {
            'title': widget.title,
            'subtitle': widget.subtitle,
            'image': widget.imageUrl ?? '',
            'url': widget.station?.playerUrl ?? ''
          };
      PlaybackManager.instance.play(current, duration: _totalSeconds);
    }
  }

  void _selectSong(int index, {bool autoplay = true}) {
    setState(() {
      _currentIndex = index;
      final s = _songs[index];
      if (autoplay) {
        PlaybackManager.instance.play(s, duration: _totalSeconds);
      } else {
        PlaybackManager.instance.play(s, duration: _totalSeconds);
        PlaybackManager.instance.pause();
      }
    });
  }

  void _playNext() {
    if (_songs.isEmpty) return;
    final next = (_currentIndex + 1) % _songs.length;
    _selectSong(next, autoplay: true);
  }

  void _playPrevious() {
    if (_songs.isEmpty) return;
    int prev = _currentIndex - 1;
    if (prev < 0) prev = _songs.length - 1;
    _selectSong(prev, autoplay: true);
  }

  void _playbackListener() {
    final mgr = PlaybackManager.instance;
    setState(() {
      _isPlaying = mgr.isPlaying;
      _progress = mgr.progress;
      _durationSeconds = mgr.durationSeconds;
      
      if (_isPlaying) {
        if (!_rotationController.isAnimating) _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
      final cur = mgr.currentSong;
      if (cur != null) {
        final idx = _songs.indexWhere((s) =>
            s['title'] == cur['title'] && s['subtitle'] == cur['subtitle']);
        if (idx != -1 && idx != _currentIndex) {
          _currentIndex = idx;
        } else if (idx == -1) {
          _songs.insert(0, Map.from(cur));
          _currentIndex = 0;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
  final double screenWidth = MediaQuery.of(context).size.width;
  final double screenHeight = MediaQuery.of(context).size.height;
  // Base album size on width, but cap it to a fraction of the screen height
  // so very tall layouts won't overflow. Keep a reasonable min/max as well.
  final double baseSize = (screenWidth * 0.55).clamp(160.0, 360.0);
  final double maxByHeight = screenHeight * 0.45;
  final double albumSize = math.min(baseSize, maxByHeight);
    final current = _songs[_currentIndex];
    final imageUrl = current['image'];

    return BakwaasScaffold(
      backgroundImage: imageUrl,
      activeTab: AppData.rootTab.value,
      showBottomNav: widget.showBottomNav,
      onMenuTap: () => Navigator.of(context).maybePop(),
      onExitTap: () => Navigator.of(context).maybePop(),
      bodyPadding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                const SizedBox(height: 12),
                SizedBox(
              width: albumSize + 64,
              height: albumSize + 64,
              child: AnimatedBuilder(
                animation: _ringController,
                builder: (context, _) {
                  final intensity = (_isPlaying ? 1.0 : 0.25);
                  return CustomPaint(
                    painter: OrbitalRingPainter(
                      tick: _ringController.value,
                      color: Colors.tealAccent,
                      intensity: intensity,
                    ),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) => Transform.rotate(
                            angle: _rotationController.value * 2 * math.pi,
                            child: child),
                        child: InteractiveViewer(
                          // allow pinch-to-zoom on the album artwork; keep pan/scale limits reasonable
                          minScale: 1.0,
                          maxScale: 3.5,
                          child: Container(
                            width: albumSize,
                            height: albumSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                  colors: [
                                    Colors.grey.shade900,
                                    Colors.grey.shade800,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 16,
                                    offset: Offset(0, 10)),
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(12),
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
                              // Do not show fallback radio icon — prefer an empty thumbnail.
                              child: null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withAlpha((0.2 * 255).round())),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    blurRadius: 20,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
                child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('♪',
                          style: TextStyle(
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Text('NOW PLAYING',
                          style: TextStyle(
                              color: Colors.white70,
                              letterSpacing: 2,
                              fontSize: 12)),
                      const SizedBox(width: 6),
                      const Text('♪',
                          style: TextStyle(
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      // Like/unlike current item
                      Builder(builder: (context) {
                        final cur = current;
                        final songMap = {
                          'title': cur['title'] ?? '',
                          'subtitle': cur['subtitle'] ?? '',
                          'image': cur['image'] ?? '',
                          'url': cur['url'] ?? ''
                        };
                        final liked = LikedSongsManager.contains(songMap);
                        return IconButton(
                          onPressed: () {
                            if (liked) {
                              LikedSongsManager.remove(songMap);
                            } else {
                              LikedSongsManager.add(songMap);
                            }
                            setState(() {});
                          },
                          icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: Colors.pinkAccent),
                        );
                      })
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(current['title'] ?? 'Dhaka FM',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                      Text(current['subtitle'] ?? 'Live Show',
                      textAlign: TextAlign.center,
                      softWrap: true,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withAlpha((0.8 * 255).round()))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: Colors.white.withAlpha((0.06 * 255).round())),
              ),
                child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    onPressed: _playPrevious,
                    icon:
                        const Icon(Icons.skip_previous, color: Colors.white70),
                    iconSize: 36,
                  ),
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [
                          Colors.greenAccent.shade400,
                          Colors.green.shade700
                        ]),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withAlpha((0.34 * 255).round()),
                            blurRadius: 22,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Center(
                        child: PlaybackManager.instance.isLoading
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.6,
                                ),
                              )
                            : Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 42,
                              ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _playNext,
                    icon: const Icon(Icons.skip_next, color: Colors.white70),
                    iconSize: 36,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Progress slider and time display (single control)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            activeTrackColor: Colors.tealAccent,
                            inactiveTrackColor: Colors.white.withAlpha((0.12 * 255).round()),
                            thumbColor: Colors.white,
                            overlayColor: Colors.tealAccent.withAlpha((0.12 * 255).round()),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: _progress.clamp(0.0, 1.0),
                            onChanged: (v) {
                              if (PlaybackManager.instance.durationSeconds > 0) {
                                PlaybackManager.instance.seek(v);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _formatTime((_durationSeconds > 0
                                ? (_progress * _durationSeconds).round()
                                : (_progress * _totalSeconds).round())
                            .toInt()),
                        style: TextStyle(color: Colors.white.withAlpha((0.75 * 255).round())),
                      ),
                    )
                  ],
                )
              ],
            ),
            // Inline system volume slider (controls Android STREAM_MUSIC)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
              child: SystemVolumeControl(),
            ),
            // const SizedBox(height: 10),
            // Padding(
            //   padding:
            //       const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            //   child: Column(
            //     children: [
            //       GestureDetector(
            //         onPanUpdate: (details) {
            //           setState(() {
            //             _volume =
            //                 (_volume - details.delta.dy / 300).clamp(0.0, 1.0);
            //             PlaybackManager.instance.setVolume(_volume);
            //           });
            //         },
            //         child: Column(
            //           children: [
            //             Stack(
            //               alignment: Alignment.center,
            //               children: [
            //                 Container(
            //                   width: 98 + (_volume * 18),
            //                   height: 98 + (_volume * 18),
            //                   decoration: BoxDecoration(
            //                     shape: BoxShape.circle,
            //                     color: Colors.transparent,
            //                     boxShadow: [
            //                       BoxShadow(
            //                         color: Colors.tealAccent
            //                             .withOpacity(0.12 + _volume * 0.28),
            //                         blurRadius: 24 + _volume * 18,
            //                         spreadRadius: 8 + _volume * 6,
            //                       )
            //                     ],
            //                   ),
            //                 ),
            //                 Container(
            //                   width: 98,
            //                   height: 98,
            //                   decoration: BoxDecoration(
            //                     shape: BoxShape.circle,
            //                     gradient: LinearGradient(
            //                         colors: [
            //                           Colors.greenAccent.shade400.withOpacity(
            //                               0.9 * (_volume * 0.6 + 0.4)),
            //                           Colors.green.shade700.withOpacity(
            //                               0.9 * (_volume * 0.6 + 0.4))
            //                         ],
            //                         begin: Alignment.topLeft,
            //                         end: Alignment.bottomRight),
            //                     boxShadow: [
            //                       BoxShadow(
            //                         color: Colors.green
            //                             .withOpacity(0.28 * (_volume + 0.1)),
            //                         blurRadius: 18 + _volume * 12,
            //                         spreadRadius: 1 + _volume * 3,
            //                       )
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
            //                 inactiveTrackColor: Colors.white.withOpacity(0.18),
            //                 thumbColor: Colors.white,
            //                 overlayColor: Colors.tealAccent.withOpacity(0.12),
            //               ),
            //               child: Slider(
            //                 value: _volume,
            //                 onChanged: (v) {
            //                   setState(() {
            //                     _volume = v;
            //                     PlaybackManager.instance.setVolume(_volume);
            //                   });
            //                 },
            //               ),
            //             ),
            //           ],
            //         ),
            //       ),
            //       const SizedBox(height: 8),
            //       // Show the quick play banner only when we have a real title
            //       if ((current['title'] ?? '').isNotEmpty)
            //         Container(
            //           margin: const EdgeInsets.symmetric(vertical: 8),
            //           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            //           decoration: BoxDecoration(
            //             color: Colors.white.withOpacity(0.06),
            //             borderRadius: BorderRadius.circular(16),
            //           ),
            //           child: Row(
            //             mainAxisSize: MainAxisSize.min,
            //             children: [
            //               Container(
            //                 width: 36,
            //                 height: 36,
            //                 decoration: const BoxDecoration(
            //                   color: Colors.white,
            //                   shape: BoxShape.circle,
            //                 ),
            //                 child: const Icon(Icons.play_arrow, color: Colors.black),
            //               ),
            //               const SizedBox(width: 10),
            //               Text("Let's Play ${current['title']}",
            //                   style: const TextStyle(
            //                       color: Colors.white,
            //                       fontWeight: FontWeight.w600)),
            //             ],
            //           ),
            //         )
            //     ],
              // ),
            // ),
            // Ensure there's some bottom spacing so the last controls are
            // comfortably above the footer when scrolled to the end.
            const SizedBox(height: 40),
            const SizedBox(height: 40),
          ],
              ),
            ),
          );
        },
      ),
    );
  }
}
