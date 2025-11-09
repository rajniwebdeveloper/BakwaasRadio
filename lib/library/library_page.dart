import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'song_page.dart';
import 'liked_songs_page.dart';
import 'albums_page.dart';
import 'artists_page.dart';
import 'downloads_page.dart';
import 'playlists_page.dart';
import 'library_data.dart';
import 'liked_songs_manager.dart';
import '../playback_manager.dart';
import '../app_data.dart';
import '../ui_helpers.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final bg = Colors.white;

  late List<Map<String, String>> _history;

  @override
  void initState() {
    super.initState();
    _history = [
      {
        'title': 'Jug Jug Jeeve',
        'subtitle': 'Vishal Mishra',
        'image': 'https://picsum.photos/200?image=70'
      },
      {
        'title': 'Hum Dum',
        'subtitle': 'Unknown Artist',
        'image': 'https://picsum.photos/200?image=30'
      },
      {
        'title': 'Shiddat (Reprise)',
        'subtitle': 'Artist',
        'image': 'https://picsum.photos/200?image=40'
      },
      {
        'title': 'Main Rahoon Ya Na Rahoon',
        'subtitle': 'Armaan Malik',
        'image': 'https://picsum.photos/200?image=20'
      },
      {
        'title': 'Barbaadiyan',
        'subtitle': 'Artist',
        'image': 'https://picsum.photos/200?image=50'
      },
      {
        'title': 'Manjha',
        'subtitle': 'Vishal Mishra',
        'image': 'https://picsum.photos/200?image=60'
      },
      {
        'title': 'Tere Sang',
        'subtitle': 'Unknown Artist',
        'image': 'https://picsum.photos/200?image=21'
      },
      {
        'title': 'Aankhon Mein',
        'subtitle': 'Some Artist',
        'image': 'https://picsum.photos/200?image=22'
      },
      {
        'title': 'Naach Meri Rani',
        'subtitle': 'Artist',
        'image': 'https://picsum.photos/200?image=23'
      },
      {
        'title': 'Tum Hi Ho',
        'subtitle': 'Arijit Singh',
        'image': 'https://picsum.photos/200?image=24'
      },
      {
        'title': 'Kesariya',
        'subtitle': 'Arijit Singh',
        'image': 'https://picsum.photos/200?image=25'
      },
      {
        'title': 'Shayad',
        'subtitle': 'Arijit Singh',
        'image': 'https://picsum.photos/200?image=26'
      },
      {
        'title': 'Bekhayali',
        'subtitle': 'Sachet Tandon',
        'image': 'https://picsum.photos/200?image=27'
      },
      {
        'title': 'Ghungroo',
        'subtitle': 'Arijit Singh',
        'image': 'https://picsum.photos/200?image=28'
      },
      {
        'title': 'Dil Diyan Gallan',
        'subtitle': 'Atif Aslam',
        'image': 'https://picsum.photos/200?image=29'
      },
      {
        'title': 'Tujh Mein Rab Dikhta Hai',
        'subtitle': 'Roop Kumar Rathod',
        'image': 'https://picsum.photos/200?image=31'
      },
      {
        'title': 'Kabira',
        'subtitle': 'Arijit / Harshdeep',
        'image': 'https://picsum.photos/200?image=32'
      },
      {
        'title': 'Channa Mereya',
        'subtitle': 'Arijit Singh',
        'image': 'https://picsum.photos/200?image=33'
      },
    ];
  }

  void _shuffleHistory() {
    setState(() {
      _history.shuffle(math.Random());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // compact header with close button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.black87)),
                  const SizedBox(width: 4),
                  const Expanded(
                      child: Text('My Library',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.settings_outlined,
                          color: Colors.black87)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // menu list (no separators)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          // Liked songs count
                          ValueListenableBuilder<List<Map<String, String>>>(
                            valueListenable: LikedSongsManager.liked,
                            builder: (context, likedList, _) {
                              final likedSongsCount = likedList.length;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  tileColor: bg,
                                  leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: const Icon(Icons.favorite_border,
                                          color: Colors.black87)),
                                  title: const Text('Liked Songs',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8.0),
                                            child: Text('$likedSongsCount',
                                                style: const TextStyle(
                                                    color: Colors.black87))),
                                        const Icon(Icons.chevron_right,
                                            color: Colors.black87)
                                      ]),
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const LikedSongsPage())),
                                ),
                              );
                            },
                          ),

                          // Albums count
                          ValueListenableBuilder<List<Map<String, String>>>(
                            valueListenable: LibraryData.albums,
                            builder: (context, albumsList, _) {
                              final albumsCount = albumsList.length;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  tileColor: bg,
                                  leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: const Icon(Icons.album,
                                          color: Colors.black87)),
                                  title: const Text('Albums',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8.0),
                                            child: Text('$albumsCount',
                                                style: const TextStyle(
                                                    color: Colors.black87))),
                                        const Icon(Icons.chevron_right,
                                            color: Colors.black87)
                                      ]),
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const AlbumsPage())),
                                ),
                              );
                            },
                          ),

                          // Artists count
                          ValueListenableBuilder<List<Map<String, String>>>(
                            valueListenable: LibraryData.artists,
                            builder: (context, artistsList, _) {
                              final artistsCount = artistsList.length;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  tileColor: bg,
                                  leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: const Icon(Icons.person,
                                          color: Colors.black87)),
                                  title: const Text('Artists',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8.0),
                                            child: Text('$artistsCount',
                                                style: const TextStyle(
                                                    color: Colors.black87))),
                                        const Icon(Icons.chevron_right,
                                            color: Colors.black87)
                                      ]),
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const ArtistsPage())),
                                ),
                              );
                            },
                          ),

                          // Downloads count
                          ValueListenableBuilder<List<Map<String, String>>>(
                            valueListenable: LibraryData.downloads,
                            builder: (context, downloadsList, _) {
                              final downloadsCount = downloadsList.length;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  tileColor: bg,
                                  leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: const Icon(Icons.download,
                                          color: Colors.black87)),
                                  title: const Text('Downloads',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8.0),
                                            child: Text('$downloadsCount',
                                                style: const TextStyle(
                                                    color: Colors.black87))),
                                        const Icon(Icons.chevron_right,
                                            color: Colors.black87)
                                      ]),
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const DownloadsPage())),
                                ),
                              );
                            },
                          ),

                          // Playlists count (use AppData)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              tileColor: bg,
                              leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.queue_music,
                                      color: Colors.black87)),
                              title: const Text('Playlists',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: Text(
                                            '${AppData.playlists.length}',
                                            style: const TextStyle(
                                                color: Colors.black87))),
                                    const Icon(Icons.chevron_right,
                                        color: Colors.black87)
                                  ]),
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const PlaylistsPage())),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Improved Shuffle & Play button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _shuffleHistory();
                          // if there is at least one song, start playback of the first
                          if (_history.isNotEmpty) {
                            final s = _history.first;
                            final songMap = {
                              'title': s['title'] ?? '',
                              'subtitle': s['subtitle'] ?? '',
                              'image': s['image'] ?? ''
                            };
                            // start global playback
                            PlaybackManager.instance
                                .play(songMap, duration: 191);
                            // open the player page
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => SongPage(
                                    title: songMap['title']!,
                                    subtitle: songMap['subtitle']!,
                                    imageUrl: songMap['image'],
                                    autoplay: true)));
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.deepPurple.shade600,
                              Colors.tealAccent
                            ]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 4))
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.shuffle,
                                    color: Colors.black),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Shuffle & Play',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700)),
                                    SizedBox(height: 2),
                                    Text(
                                        'Shuffle your library and start playing',
                                        style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.play_arrow,
                                  color: Colors.black87)
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // history header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('History',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(
                              onPressed: () {},
                              child: const Text('Clear',
                                  style: TextStyle(color: Colors.tealAccent))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // history list
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 0),
                      itemBuilder: (context, index) {
                        final s = _history[index];
                        final songMap = {
                          'title': s['title'] ?? '',
                          'subtitle': s['subtitle'] ?? '',
                          'image': s['image'] ?? ''
                        };
                        final isLiked = LikedSongsManager.contains(songMap);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.grey.shade200,
                                  image: DecorationImage(
                                      image: NetworkImage(s['image']!),
                                      fit: BoxFit.cover))),
                          title: Text(s['title'] ?? '',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          subtitle: Text(s['subtitle'] ?? '',
                              style: const TextStyle(color: Colors.black87)),
                          trailing: PopupMenuButton<String>(
                              color: bg,
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.black87),
                              onSelected: (value) {
                                if (value == 'like') {
                                  if (isLiked) {
                                    LikedSongsManager.remove(songMap);
                                  } else {
                                    LikedSongsManager.add(songMap);
                                  }
                                  setState(() {});
                                  return;
                                }
                                if (value == 'add_playlist') {
                                  showAddToPlaylistSheet(context, songMap);
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$value selected')));
                              },
                              itemBuilder: (_) => [
                                    PopupMenuItem(
                                        value: 'like',
                                        child: Row(children: [
                                          Icon(Icons.favorite,
                                              color: isLiked
                                                  ? Colors.red
                                                  : Colors.black87),
                                          const SizedBox(width: 8),
                                          Text(isLiked ? 'Liked' : 'Like',
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
                                        ]))
                                  ]),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => SongPage(
                                      title: s['title'] ?? '',
                                      subtitle: s['subtitle'] ?? '',
                                      imageUrl: s['image']))),
                        );
                      },
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
