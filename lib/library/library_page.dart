import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../stations_page.dart';
import 'song_page.dart';
import 'liked_songs_page.dart';
import 'albums_page.dart';
import 'artists_page.dart';
import 'downloads_page.dart';
import 'playlists_page.dart';
import 'library_data.dart';
import 'liked_songs_manager.dart';
import '../playback_manager.dart';
import '../widgets/bakwaas_chrome.dart';
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
    // No demo history — use real history when available.
    // Prefer persisted playback history from PlaybackManager if available
    _history = PlaybackManager.instance.history;
  }

  // sort directions for sections: true = ascending, false = descending
  bool _stationsAsc = true;
  bool _recentAsc = false;
  bool _songsAsc = true;

  void _shuffleHistory() {
    setState(() {
      _history.shuffle(math.Random());
    });
  }

  // Helper to build section header with title, view all and sort toggle
  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll, VoidCallback? onSortToggle}) {
    return Row(
      children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        IconButton(
            icon: const Icon(Icons.sort, color: Colors.black87, size: 20),
            onPressed: onSortToggle),
        TextButton(
            onPressed: onViewAll ?? () {},
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('VIEW ALL', style: TextStyle(color: Colors.black87, fontSize: 12)),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.black54, size: 18)
            ]))
      ],
    );
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

                    // --- Stations / Recently Playing / Songs sections ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          _buildSectionHeader('Stations', onViewAll: () {
                            Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const StationsPage()));
                          }, onSortToggle: () => setState(() => _stationsAsc = !_stationsAsc)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 160,
                            child: FutureBuilder(
                              future: ApiService.getStations(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  final stations = (snapshot.data as List).cast();
                                  final list = _stationsAsc ? stations : stations.reversed.toList();
                                  final visible = list.take(6).toList();
                                  return ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: visible.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                                    itemBuilder: (context, idx) {
                                      final station = visible[idx];
                                      return SizedBox(
                                        width: 200,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                              builder: (_) => SongPage(
                                                    station: station,
                                                    title: station.name,
                                                    subtitle: station.description ?? '',
                                                    imageUrl: station.profilepic,
                                                    autoplay: true,
                                                  ))),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BakwaasTheme.glassDecoration(radius: 18, opacity: 0.08),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: Container(
                                                      width: double.infinity,
                                                      decoration: BoxDecoration(
                                                        image: (station.profilepic != null && station.profilepic!.isNotEmpty)
                                                            ? DecorationImage(image: NetworkImage(station.profilepic!), fit: BoxFit.cover)
                                                            : const DecorationImage(image: AssetImage('assets/logo.png'), fit: BoxFit.cover),
                                                        color: Colors.white.withOpacity(0.03),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                } else if (snapshot.hasError) {
                                  return Center(child: Text('Failed to load', style: TextStyle(color: Colors.white.withOpacity(0.7))));
                                }
                                return const Center(child: CircularProgressIndicator(color: BakwaasPalette.neonGreen));
                              },
                            ),
                          ),

                          const SizedBox(height: 18),
                          _buildSectionHeader('Recently Playing', onViewAll: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => FullSongsPage(title: 'Recently Played', songs: _history)));
                          }, onSortToggle: () => setState(() => _recentAsc = !_recentAsc)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 140,
                            child: _history.isEmpty
                                ? Center(
                                    child: Text('No recently played items', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                                  )
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: (_history.length > 6) ? 6 : _history.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                                    itemBuilder: (context, idx) {
                                      final list = _recentAsc ? _history.reversed.toList() : _history;
                                      final s = list[idx];
                                      return SizedBox(
                                        width: 220,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongPage(title: s['title'] ?? '', subtitle: s['subtitle'] ?? '', imageUrl: s['image']))),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BakwaasTheme.glassDecoration(radius: 14, opacity: 0.08),
                                            child: Row(
                                              children: [
                                                CircleAvatar(radius: 36, backgroundImage: s['image'] != null && s['image']!.isNotEmpty ? NetworkImage(s['image']!) : const AssetImage('assets/logo.png') as ImageProvider, backgroundColor: Colors.white.withOpacity(0.04)),
                                                const SizedBox(width: 12),
                                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                                  Text(s['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                                  const SizedBox(height: 6),
                                                  Text(s['subtitle'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.75)))
                                                ]))
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          const SizedBox(height: 18),
                          _buildSectionHeader('Songs', onViewAll: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => FullSongsPage(title: 'All Songs', songs: _history)));
                          }, onSortToggle: () => setState(() => _songsAsc = !_songsAsc)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 140,
                            child: _history.isEmpty
                                ? Center(child: Text('No songs yet', style: TextStyle(color: Colors.white.withOpacity(0.7))))
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: (_history.length > 6) ? 6 : _history.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                                    itemBuilder: (context, idx) {
                                      final list = _songsAsc ? _history : _history.reversed.toList();
                                      final s = list[idx];
                                      return SizedBox(
                                        width: 160,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongPage(title: s['title'] ?? '', subtitle: s['subtitle'] ?? '', imageUrl: s['image']))),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BakwaasTheme.glassDecoration(radius: 12, opacity: 0.08),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(child: Container(decoration: BoxDecoration(image: s['image'] != null && s['image']!.isNotEmpty ? DecorationImage(image: NetworkImage(s['image']!), fit: BoxFit.cover) : const DecorationImage(image: AssetImage('assets/logo.png'), fit: BoxFit.cover), color: Colors.white.withOpacity(0.04)))),
                                                const SizedBox(height: 8),
                                                Text(s['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),

                    // Improved Shuffle & Play button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                          onTap: _history.isNotEmpty ? () {
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
                              PlaybackManager.instance.play(songMap, duration: 191);
                              // open the player page
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => SongPage(
                                      title: songMap['title']!,
                                      subtitle: songMap['subtitle']!,
                                      imageUrl: songMap['image'],
                                      autoplay: true)));
                            }
                          } : null,
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
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                  image: s['image'] != null && s['image']!.isNotEmpty ? NetworkImage(s['image']!) : const AssetImage('assets/logo.png') as ImageProvider,
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
                                    const PopupMenuItem(
                                        value: 'add_playlist',
                                        child: Row(children: [
                                          Icon(Icons.playlist_add,
                                              color: Colors.black87),
                                          SizedBox(width: 8),
                                          Text('Add to playlist',
                                              style: TextStyle(
                                                  color: Colors.black))
                                        ])),
                                    const PopupMenuItem(
                                        value: 'download',
                                        child: Row(children: [
                                          Icon(Icons.download,
                                              color: Colors.black87),
                                          SizedBox(width: 8),
                                          Text('Download',
                                              style: TextStyle(
                                                  color: Colors.black))
                                        ])),
                                    const PopupMenuItem(
                                        value: 'add_queue',
                                        child: Row(children: [
                                          Icon(Icons.queue_music,
                                              color: Colors.black87),
                                          SizedBox(width: 8),
                                          Text('Add to queue',
                                              style: TextStyle(
                                                  color: Colors.black))
                                        ])),
                                    const PopupMenuItem(
                                        value: 'share',
                                        child: Row(children: [
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

// Simple full-page listing for songs used by LibraryPage
class FullSongsPage extends StatelessWidget {
  final String title;
  final List<Map<String, String>> songs;
  const FullSongsPage({super.key, required this.title, required this.songs});

  @override
  Widget build(BuildContext context) {
    final cover = songs.isNotEmpty ? songs.first['image'] : null;
    return BakwaasScaffold(
      backgroundImage: cover,
      activeTab: 2,
      onMenuTap: () => Navigator.of(context).maybePop(),
      onExitTap: () => Navigator.of(context).maybePop(),
      bodyPadding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
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
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SongPage(title: s['title'] ?? '', subtitle: s['subtitle'] ?? '', imageUrl: s['image']))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BakwaasTheme.glassDecoration(radius: 18, opacity: 0.08),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 28, backgroundImage: s['image'] != null && s['image']!.isNotEmpty ? NetworkImage(s['image']!) : const AssetImage('assets/logo.png') as ImageProvider, backgroundColor: Colors.white.withOpacity(0.08)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['title'] ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(s['subtitle'] ?? '', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70, size: 20)
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
