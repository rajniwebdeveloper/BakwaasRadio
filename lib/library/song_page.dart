import 'dart:math' as math;
import 'dart:ui';
import 'package:bakwaas_fm/models/station.dart';
import 'package:flutter/material.dart';
import '../playback_manager.dart';
import '../app_data.dart';
import 'liked_songs_manager.dart';

class SongPage extends StatefulWidget {
  final Station? station;
  final String title;
  final String subtitle;
  final String? imageUrl; // optional image to show inside the CD
  final bool autoplay; // whether to auto-start playback when opened
  const SongPage(
      {super.key,
      this.station,
      required this.title,
      required this.subtitle,
      this.imageUrl,
      this.autoplay = false});

  @override
  State<SongPage> createState() => _SongPageState();
}

class _SongPageState extends State<SongPage> with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _ringController;
  bool _isPlaying = false;
  double _progress = 0.0;
  double _volume = 1.0;

  // sample song list
  final List<Map<String, String>> _songs = [
    {
      'title': 'Manjha',
      'subtitle': 'Vishal Mishra',
      'image': 'https://picsum.photos/400?image=10'
    },
    {
      'title': 'Main Rahoon Ya Na Rahoon',
      'subtitle': 'Armaan Malik',
      'image': 'https://picsum.photos/400?image=20'
    },
    {
      'title': 'Hum Dum',
      'subtitle': 'Unknown Artist',
      'image': 'https://picsum.photos/400?image=30'
    },
    {
      'title': 'Shiddat (Reprise)',
      'subtitle': 'Artist',
      'image': 'https://picsum.photos/400?image=40'
    },
    {
      'title': 'Barbaadiyan',
      'subtitle': 'Artist',
      'image': 'https://picsum.photos/400?image=50'
    },
  ];

  int _currentIndex = 0;
  static const int _totalSeconds = 3 * 60 + 11; // 3:11

  @override
  void initState() {
    super.initState();
    _rotationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10));
    _ringController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
          ..repeat();

    _volume = PlaybackManager.instance.volume;

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
        'image': widget.imageUrl ?? 'https://picsum.photos/400?image=60'
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

  bool _isLiked(Map<String, String> song) {
    return LikedSongsManager.contains(song);
  }

  void _toggleLike(Map<String, String> song) {
    if (_isLiked(song)) {
      LikedSongsManager.remove(song);
    } else {
      LikedSongsManager.add(song);
    }
    setState(() {});
  }

  void _playbackListener() {
    final mgr = PlaybackManager.instance;
    setState(() {
      _isPlaying = mgr.isPlaying;
      _progress = mgr.progress;
      _volume = mgr.volume;
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

  void _showAddToPlaylistSheet(Map<String, String> song) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
        builder: (ctx) {
          final lists = AppData.playlists;
          final nameController = TextEditingController();
          bool creating = false;
          return SafeArea(
            child: StatefulBuilder(builder: (ctx2, setStateSB) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(width: 40, height: 4, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Add to playlist',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),

                  if (creating)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameController,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                hintText: 'Playlist name',
                                hintStyle: TextStyle(color: Colors.grey),
                                enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Enter a name')));
                                return;
                              }
                              AppData.playlists.add({
                                'title': name,
                                'songs': [Map.from(song)],
                                'image': null,
                              });
                              setState(() {
                                creating = false;
                                nameController.clear();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Created "$name" and added song')));
                            },
                            child: const Text('Add',
                                style: TextStyle(color: Colors.tealAccent)),
                          )
                        ],
                      ),
                    ),

                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: lists.length,
                      separatorBuilder: (_, __) => const Divider(
                          color: Color.fromARGB(255, 238, 238, 238)),
                      itemBuilder: (context, i) {
                        final p = lists[i];
                        return ListTile(
                          leading: CircleAvatar(
                              backgroundImage: p['image'] != null
                                  ? NetworkImage(p['image'])
                                  : null,
                              backgroundColor: Colors.grey.shade200),
                          title: Text(p['title'] ?? '',
                              style: const TextStyle(color: Colors.black)),
                          subtitle: Text('${(p['songs'] as List).length} songs',
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 12)),
                          onTap: () {
                            (p['songs'] as List).add(Map.from(song));
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Added to ${p['title']}')));
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.black87),
                            onPressed: () {
                              (p['songs'] as List).add(Map.from(song));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Added to ${p['title']}')));
                            },
                          ),
                        );
                      },
                    ),
                  )
                ],
              );
            }),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    const double albumSize = 260.0;
    final current = _songs[_currentIndex];
    final imageUrl = current['image'];

    final bgGradient = const LinearGradient(
      colors: [Color(0xFF071029), Color(0xFF1B0330)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(gradient: bgGradient),
          child: Stack(
            children: [
              // blurred full-screen album background (dimmed)
              if (imageUrl != null && imageUrl.isNotEmpty)
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Opacity(
                      opacity: 0.70,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.black),
                      ),
                    ),
                  ),
                ),

              // soft translucent overlay to darken background a bit more
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.28)),
              ),

              Column(
                children: [
                  // top bar with centered title and left/right actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.menu, color: Colors.white),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.exit_to_app, color: Colors.white),
                            ),
                          ],
                        ),
                        // centered title
                        Center(
                          child: Text(
                            'BAKWAAS FM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              // slight geometric retro feel with heavy weight
                            ),
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // rotating vinyl with animated orbital ring
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // animated orbital ring painter
                          SizedBox(
                            width: albumSize + 64,
                            height: albumSize + 64,
                            child: AnimatedBuilder(
                              animation: _ringController,
                              builder: (context, _) {
                                // ring reacts more strongly when playing
                                final intensity = (_isPlaying ? 1.0 : 0.25);
                                return CustomPaint(
                                  painter: _OrbitalRingPainter(
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
                                      child: Container(
                                        width: albumSize,
                                        height: albumSize,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                              colors: [
                                                Colors.grey.shade900,
                                                Colors.black
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black.withOpacity(0.6),
                                                blurRadius: 20,
                                                offset: const Offset(0, 12))
                                          ],
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: albumSize - 40,
                                            height: albumSize - 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.grey.shade900,
                                              boxShadow: [
                                                BoxShadow(
                                                    color: Colors.black.withOpacity(0.4),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 6))
                                              ],
                                            ),
                                            child: ClipOval(
                                              child: imageUrl != null && imageUrl.isNotEmpty
                                                  ? Image.network(imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) =>
                                                          Container(color: Colors.grey.shade900))
                                                  : Container(
                                                      color: Colors.grey.shade900,
                                                      child: const Center(
                                                          child: Icon(Icons.album,
                                                              size: 64,
                                                              color: Colors.white70))),
                                            ),
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

                          // NOW PLAYING tag (musical style)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: const Text('♪ NOW PLAYING ♪',
                                style: TextStyle(
                                    color: Colors.tealAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2)),
                          ),

                          const SizedBox(height: 8),

              // Station title (use provided title or station name)
              Text('Dhaka FM',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(current['subtitle'] ?? widget.subtitle,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                  // player capsule controls
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(48),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // previous
                              IconButton(
                                onPressed: _playPrevious,
                                icon: const Icon(Icons.skip_previous,
                                    color: Colors.white70),
                                iconSize: 36,
                              ),

                              // play button (green)
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
                                        color: Colors.green.withOpacity(0.34),
                                        blurRadius: 22,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      _isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 42,
                                    ),
                                  ),
                                ),
                              ),

                              // next
                              IconButton(
                                onPressed: _playNext,
                                icon:
                                    const Icon(Icons.skip_next, color: Colors.white70),
                                iconSize: 36,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // progress slider with label
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0, vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 4,
                                        activeTrackColor: Colors.tealAccent,
                                        inactiveTrackColor:
                                            Colors.white.withOpacity(0.12),
                                        thumbColor: Colors.white,
                                        overlayColor:
                                            Colors.tealAccent.withOpacity(0.12),
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 8),
                                      ),
                                      child: Slider(
                                        value: _progress.clamp(0.0, 1.0),
                                        onChanged: (v) =>
                                            PlaybackManager.instance.seek(v),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                      _isPlaying ? "Now Playing..." : "Let's Play...",
                                      style: TextStyle(
                                          color:
                                              Colors.white.withOpacity(0.75))),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(_formatTime((_progress * _totalSeconds).round()),
                                      style: TextStyle(
                                          color:
                                              Colors.white.withOpacity(0.75))),
                                )
                              ],
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                    // volume control block
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                      child: Column(
                        children: [
                          // glowing knob
                          GestureDetector(
                            onPanUpdate: (details) {
                              // vertical drag changes volume
                              setState(() {
                                _volume = (_volume - details.delta.dy / 300).clamp(0.0, 1.0);
                                PlaybackManager.instance.setVolume(_volume);
                              });
                            },
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // radial glow that expands with volume
                                    Container(
                                      width: 98 + (_volume * 18),
                                      height: 98 + (_volume * 18),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.transparent,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.tealAccent.withOpacity(0.12 + _volume * 0.28),
                                            blurRadius: 24 + _volume * 18,
                                            spreadRadius: 8 + _volume * 6,
                                          )
                                        ],
                                      ),
                                    ),

                                    // knob
                                    Container(
                                      width: 98,
                                      height: 98,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(colors: [
                                          Colors.greenAccent.shade400.withOpacity(0.9 * (_volume * 0.6 + 0.4)),
                                          Colors.green.shade700.withOpacity(0.9 * (_volume * 0.6 + 0.4))
                                        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green.withOpacity(0.28 * (_volume + 0.1)),
                                            blurRadius: 18 + _volume * 12,
                                            spreadRadius: 1 + _volume * 3,
                                          )
                                        ],
                                      ),
                                      child: Transform.rotate(
                                        angle: (_volume - 0.5) * math.pi, // rotate knob with volume
                                        child: const Center(
                                          child: Icon(Icons.volume_up, color: Colors.white, size: 36),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),
                                // slim white volume slider
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white.withOpacity(0.18),
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.tealAccent.withOpacity(0.12),
                                  ),
                                  child: Slider(
                                    value: _volume,
                                    onChanged: (v) {
                                      setState(() {
                                        _volume = v;
                                        PlaybackManager.instance.setVolume(_volume);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // bottom mini banner
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow, color: Colors.black),
                                ),
                                const SizedBox(width: 10),
                                const Text("Let's Play Dhaka FM",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 14)
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04))),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home with yellow highlight bubble
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE082),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFFFFE082).withOpacity(0.28), blurRadius: 12, spreadRadius: 1)],
                  ),
                  child: const Icon(Icons.home, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                const Text('Home', style: TextStyle(color: Colors.white70, fontSize: 12))
              ],
            ),

            // Heart
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.favorite_border, color: Colors.white70, size: 28),
                SizedBox(height: 6),
                Text('Liked', style: TextStyle(color: Colors.white70, fontSize: 12))
              ],
            ),

            // Radio
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.radio, color: Colors.white70, size: 28),
                SizedBox(height: 6),
                Text('Radio', style: TextStyle(color: Colors.white70, fontSize: 12))
              ],
            ),

            // Settings/info
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.info_outline, color: Colors.white70, size: 28),
                SizedBox(height: 6),
                Text('Info', style: TextStyle(color: Colors.white70, fontSize: 12))
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitalRingPainter extends CustomPainter {
  final double tick; // 0..1 animation tick
  final Color color;
  final double intensity; // 0..1 reaction intensity

  _OrbitalRingPainter({required this.tick, required this.color, this.intensity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 6;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // draw several thin arcs with varying alpha/length driven by sin waves
    final rings = 5;
    for (int i = 0; i < rings; i++) {
      final phase = tick * 2 * math.pi + (i * 0.9);
      final amp = 0.6 + 0.4 * math.sin(phase * (1 + i * 0.2));
      final width = 1.2 + i * 0.6;
      paint.strokeWidth = width;
      final alpha = (160 * amp * intensity).clamp(18, 220).toInt();
      paint.color = color.withAlpha(alpha);

      // draw multiple small arc segments around the circle
      final segments = 60 - i * 6;
      for (int s = 0; s < segments; s++) {
        final start = (s / segments) * 2 * math.pi + (i * 0.12) + tick * 2 * math.pi * (0.4 + i * 0.2);
        final sweep = 0.06 + 0.02 * math.sin(phase + s * 0.12);
        final path = Path();
        path.addArc(Rect.fromCircle(center: center, radius: radius - i * 4), start, sweep);
        canvas.drawPath(path, paint);
      }
    }

    // subtle outer glow ring
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withAlpha((30 * intensity).toInt());
    canvas.drawCircle(center, radius + 6, glow);
  }

  @override
  bool shouldRepaint(covariant _OrbitalRingPainter old) {
    return old.tick != tick || old.intensity != intensity || old.color != color;
  }
}
