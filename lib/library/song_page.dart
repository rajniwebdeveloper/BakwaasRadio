import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'liked_songs_manager.dart';
import '../playback_manager.dart';
import '../app_data.dart';

class SongPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imageUrl; // optional image to show inside the CD
  final bool autoplay; // whether to auto-start playback when opened
  const SongPage(
      {super.key,
      required this.title,
      required this.subtitle,
      this.imageUrl,
      this.autoplay = false});

  @override
  State<SongPage> createState() => _SongPageState();
}

class _SongPageState extends State<SongPage> with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  bool _isPlaying = false;
  double _progress = 0.0;

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

    // listen to global playback manager
    PlaybackManager.instance.addListener(_playbackListener);

    // if widget provides a specific song, insert it at top
    if (widget.title.isNotEmpty) {
      _songs.insert(0, {
        'title': widget.title,
        'subtitle': widget.subtitle,
        'image': widget.imageUrl ?? 'https://picsum.photos/400?image=60'
      });
      _currentIndex = 0;
      // start playing immediately if requested
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
            'image': widget.imageUrl ?? ''
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
        // only select but don't autoplay: update manager current song but paused
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
      if (_isPlaying) {
        if (!_rotationController.isAnimating) _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
      // if manager song differs, update current index/current song
      final cur = mgr.currentSong;
      if (cur != null) {
        final idx = _songs.indexWhere((s) =>
            s['title'] == cur['title'] && s['subtitle'] == cur['subtitle']);
        if (idx != -1 && idx != _currentIndex) {
          _currentIndex = idx;
        } else if (idx == -1) {
          // add to list if missing
          _songs.insert(0, Map.from(cur));
          _currentIndex = 0;
        }
      }
    });
  }

  // show bottom sheet to add given song to a playlist
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

                  // Create new playlist row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.create_new_folder,
                          color: Colors.black87),
                      title: const Text('Create new playlist',
                          style: TextStyle(color: Colors.black)),
                      trailing: IconButton(
                          icon: const Icon(Icons.add, color: Colors.black87),
                          onPressed: () {
                            setStateSB(() {
                              creating = !creating;
                            });
                          }),
                      onTap: () {
                        setStateSB(() {
                          creating = !creating;
                        });
                      },
                    ),
                  ),

                  // Inline creation UI
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
                              // create playlist and add the song
                              AppData.playlists.add({
                                'title': name,
                                'songs': [Map.from(song)],
                                'image': null,
                              });
                              setStateSB(() {
                                creating = false;
                                nameController.clear();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Created "$name" and added song')));
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
                            // add song and close
                            (p['songs'] as List).add(Map.from(song));
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Added to ${p['title']}')));
                          },
                          // quick-add plus button that keeps sheet open
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.black87),
                            onPressed: () {
                              (p['songs'] as List).add(Map.from(song));
                              setStateSB(() {});
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
    const double albumSize = 220.0;
    final current = _songs[_currentIndex];
    final imageUrl = current['image'];
    final bg = Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // fixed header (does not scroll)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(current['title'] ?? '',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(current['subtitle'] ?? '',
                            style: const TextStyle(
                                color: Colors.black87, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  // IconButton(
                  //     icon: Icon(
                  //         _isLiked(current)
                  //             ? Icons.favorite
                  //             : Icons.favorite_border,
                  //         color: _isLiked(current)
                  //             ? Colors.white
                  //             : Colors.white70),
                  //     onPressed: () => _toggleLike(current),
                  //     iconSize: 24),
                  PopupMenuButton<String>(
                    color: bg,
                    icon: const Icon(Icons.more_vert, color: Colors.black87),
                    onSelected: (value) {
                      if (value == 'like') {
                        final song = {
                          'title': current['title'] ?? '',
                          'subtitle': current['subtitle'] ?? '',
                          'image': current['image'] ?? ''
                        };
                        _toggleLike(song);
                        return;
                      }
                      if (value == 'add_playlist') {
                        final song = {
                          'title': current['title'] ?? '',
                          'subtitle': current['subtitle'] ?? '',
                          'image': current['image'] ?? ''
                        };
                        _showAddToPlaylistSheet(song);
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$value selected')));
                    },
                    itemBuilder: (_) {
                      final song = {
                        'title': current['title'] ?? '',
                        'subtitle': current['subtitle'] ?? '',
                        'image': current['image'] ?? ''
                      };
                      final liked = _isLiked(song);
                      return [
                        PopupMenuItem(
                            value: 'like',
                            child: Row(children: [
                              Icon(Icons.favorite,
                                  color: liked ? Colors.red : Colors.black87),
                              const SizedBox(width: 8),
                              Text(liked ? 'Liked' : 'Like',
                                  style: const TextStyle(color: Colors.black))
                            ])),
                        PopupMenuItem(
                            value: 'add_playlist',
                            child: Row(children: const [
                              Icon(Icons.playlist_add, color: Colors.black87),
                              SizedBox(width: 8),
                              Text('Add to playlist',
                                  style: TextStyle(color: Colors.black))
                            ])),
                        PopupMenuItem(
                            value: 'download',
                            child: Row(children: const [
                              Icon(Icons.download, color: Colors.black87),
                              SizedBox(width: 8),
                              Text('Download',
                                  style: TextStyle(color: Colors.black))
                            ])),
                        PopupMenuItem(
                            value: 'add_queue',
                            child: Row(children: const [
                              Icon(Icons.queue_music, color: Colors.black87),
                              SizedBox(width: 8),
                              Text('Add to queue',
                                  style: TextStyle(color: Colors.black))
                            ])),
                        PopupMenuItem(
                            value: 'share',
                            child: Row(children: const [
                              Icon(Icons.share, color: Colors.black87),
                              SizedBox(width: 8),
                              Text('Share',
                                  style: TextStyle(color: Colors.black))
                            ])),
                      ];
                    },
                  ),
                ],
              ),
            ),

            // scrollable content
            Expanded(
              child: Container(
                color: bg, // ensure scroll area background matches scaffold
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),

                      // rotating CD
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: Container(
                            width: albumSize,
                            height: albumSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                Colors.grey.shade300,
                                Colors.grey.shade500
                              ]),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 20,
                                    offset: Offset(0, 10))
                              ],
                            ),
                            child: AnimatedBuilder(
                              animation: _rotationController,
                              builder: (context, child) => Transform.rotate(
                                  angle:
                                      _rotationController.value * 2 * math.pi,
                                  child: child),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // inner image
                                  Container(
                                    width: albumSize - 28,
                                    height: albumSize - 28,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey.shade200),
                                    child: ClipOval(
                                      child: imageUrl != null
                                          ? Image.network(imageUrl,
                                              fit: BoxFit.cover,
                                              width: albumSize - 28,
                                              height: albumSize - 28,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                      color:
                                                          Colors.grey.shade200))
                                          : Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(
                                                  child: Icon(Icons.album,
                                                      size: 80,
                                                      color: Colors.black87))),
                                    ),
                                  ),

                                  // central hole
                                  Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                          color: Colors.black,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 2)))
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // title + menu
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(current['title'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(current['subtitle'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.black87, fontSize: 13)),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              color: bg,
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.black87),
                              onSelected: (value) {
                                if (value == 'like') {
                                  final song = {
                                    'title': current['title'] ?? '',
                                    'subtitle': current['subtitle'] ?? '',
                                    'image': current['image'] ?? ''
                                  };
                                  _toggleLike(song);
                                  return;
                                }
                                if (value == 'add_playlist') {
                                  final song = {
                                    'title': current['title'] ?? '',
                                    'subtitle': current['subtitle'] ?? '',
                                    'image': current['image'] ?? ''
                                  };
                                  _showAddToPlaylistSheet(song);
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$value selected')));
                              },
                              itemBuilder: (_) {
                                final song = {
                                  'title': current['title'] ?? '',
                                  'subtitle': current['subtitle'] ?? '',
                                  'image': current['image'] ?? ''
                                };
                                final liked = _isLiked(song);
                                return [
                                  PopupMenuItem(
                                      value: 'like',
                                      child: Row(children: [
                                        Icon(Icons.favorite,
                                            color: liked
                                                ? Colors.red
                                                : Colors.black87),
                                        const SizedBox(width: 8),
                                        Text(liked ? 'Liked' : 'Like',
                                            style: const TextStyle(
                                                color: Colors.black))
                                      ])),
                                  PopupMenuItem(
                                      value: 'add_playlist',
                                      child: Row(children: const [
                                        Icon(Icons.playlist_add,
                                            color: Colors.black87),
                                        SizedBox(width: 8),
                                        Text('Add to playlist',
                                            style:
                                                TextStyle(color: Colors.black))
                                      ])),
                                  PopupMenuItem(
                                      value: 'download',
                                      child: Row(children: const [
                                        Icon(Icons.download,
                                            color: Colors.black87),
                                        SizedBox(width: 8),
                                        Text('Download',
                                            style:
                                                TextStyle(color: Colors.black))
                                      ])),
                                  PopupMenuItem(
                                      value: 'add_queue',
                                      child: Row(children: const [
                                        Icon(Icons.queue_music,
                                            color: Colors.black87),
                                        SizedBox(width: 8),
                                        Text('Add to queue',
                                            style:
                                                TextStyle(color: Colors.black))
                                      ])),
                                  PopupMenuItem(
                                      value: 'share',
                                      child: Row(children: const [
                                        Icon(Icons.share,
                                            color: Colors.black87),
                                        SizedBox(width: 8),
                                        Text('Share',
                                            style:
                                                TextStyle(color: Colors.black))
                                      ])),
                                ];
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // progress slider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            final cur = (_progress * _totalSeconds).round();
                            return Column(
                              children: [
                                Slider(
                                    value: _progress.clamp(0.0, 1.0),
                                    onChanged: (v) => PlaybackManager.instance
                                        .seek(v.clamp(0.0, 1.0)),
                                    activeColor: Colors.tealAccent,
                                    inactiveColor: Colors.grey.shade300),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatTime(cur),
                                          style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 12)),
                                      Text(_formatTime(_totalSeconds),
                                          style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 12))
                                    ])
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 8),

                      // controls
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 8),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                  icon: Icon(
                                      _isLiked(current)
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: _isLiked(current)
                                          ? Colors.red
                                          : Colors.black87),
                                  onPressed: () => _toggleLike(current),
                                  iconSize: 24),
                              IconButton(
                                  icon: const Icon(Icons.skip_previous,
                                      color: Colors.black),
                                  onPressed: _playPrevious,
                                  iconSize: 28),
                              Container(
                                  height: 64,
                                  width: 64,
                                  decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle),
                                  child: IconButton(
                                      icon: Icon(
                                          _isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          color: Colors.white,
                                          size:
                                              32), // This should be white for contrast
                                      onPressed: _togglePlay)),
                              IconButton(
                                  icon: const Icon(Icons.skip_next,
                                      color: Colors.black),
                                  onPressed: _playNext,
                                  iconSize: 28),
                              IconButton(
                                  icon: const Icon(Icons.cast,
                                      color: Colors.black87),
                                  onPressed: () {},
                                  iconSize: 22),
                            ]),
                      ),

                      const SizedBox(height: 8),

                      // song list (integrated and same background)
                      Container(
                        color: bg, // match scaffold background
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12),
                              child: Text('Up Next',
                                  style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                            ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: _songs.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: Color.fromARGB(255, 240, 240, 240)),
                              itemBuilder: (context, index) {
                                // The divider color should be updated
                                final s = _songs[index];
                                final isActive = index == _currentIndex;
                                final img = s['image'];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  leading: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage: img != null
                                          ? NetworkImage(img)
                                          : null,
                                      child: img == null
                                          ? const Icon(Icons.album,
                                              color: Colors.black87)
                                          : null),
                                  title: Text(s['title'] ?? '',
                                      style: TextStyle(
                                          color: isActive
                                              ? Colors.tealAccent
                                              : Colors.black,
                                          fontWeight: isActive
                                              ? FontWeight.w600
                                              : FontWeight.normal),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(s['subtitle'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.black87, fontSize: 12)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                            isActive && _isPlaying
                                                ? Icons.pause_circle
                                                : Icons.play_circle,
                                            color: Colors.black,
                                            size: 28),
                                        onPressed: () =>
                                            _selectSong(index, autoplay: true),
                                      ),
                                      PopupMenuButton<String>(
                                        color: bg,
                                        icon: const Icon(Icons.more_vert,
                                            color: Colors.black87),
                                        onSelected: (value) {
                                          if (value == 'like') {
                                            final song = {
                                              'title': s['title'] ?? '',
                                              'subtitle': s['subtitle'] ?? '',
                                              'image': s['image'] ?? ''
                                            };
                                            if (LikedSongsManager.contains(
                                                song)) {
                                              LikedSongsManager.remove(song);
                                            } else {
                                              LikedSongsManager.add(song);
                                            }
                                            setState(() {});
                                            return;
                                          }
                                          if (value == 'add_playlist') {
                                            final song = {
                                              'title': s['title'] ?? '',
                                              'subtitle': s['subtitle'] ?? '',
                                              'image': s['image'] ?? ''
                                            };
                                            _showAddToPlaylistSheet(song);
                                            return;
                                          }
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content:
                                                      Text('$value selected')));
                                        },
                                        itemBuilder: (_) {
                                          final song = {
                                            'title': s['title'] ?? '',
                                            'subtitle': s['subtitle'] ?? '',
                                            'image': s['image'] ?? ''
                                          };
                                          final liked =
                                              LikedSongsManager.contains(song);
                                          return [
                                            PopupMenuItem(
                                              value: 'like',
                                              child: Row(children: [
                                                Icon(Icons.favorite,
                                                    color: liked
                                                        ? Colors.red
                                                        : Colors.black87),
                                                const SizedBox(width: 8),
                                                Text(liked ? 'Liked' : 'Like',
                                                    style: const TextStyle(
                                                        color: Colors.black))
                                              ]),
                                            ),
                                            PopupMenuItem(
                                                value: 'add_playlist',
                                                child: Row(children: const [
                                                  Icon(Icons.playlist_add,
                                                      color: Colors.black87),
                                                  SizedBox(width: 8),
                                                  Text('Add to playlist',
                                                      style: TextStyle(
                                                          color: Colors.black))
                                                ])),
                                            PopupMenuItem(
                                                value: 'download',
                                                child: Row(children: const [
                                                  Icon(Icons.download,
                                                      color: Colors.black87),
                                                  SizedBox(width: 8),
                                                  Text('Download',
                                                      style: TextStyle(
                                                          color: Colors.black))
                                                ])),
                                            PopupMenuItem(
                                                value: 'add_queue',
                                                child: Row(children: const [
                                                  Icon(Icons.queue_music,
                                                      color: Colors.black87),
                                                  SizedBox(width: 8),
                                                  Text('Add to queue',
                                                      style: TextStyle(
                                                          color: Colors.black))
                                                ])),
                                            PopupMenuItem(
                                                value: 'share',
                                                child: Row(children: const [
                                                  Icon(Icons.share,
                                                      color: Colors.black87),
                                                  SizedBox(width: 8),
                                                  Text('Share',
                                                      style: TextStyle(
                                                          color: Colors.black))
                                                ])),
                                          ];
                                        },
                                      ),
                                    ],
                                  ),
                                  onTap: () =>
                                      _selectSong(index, autoplay: false),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
