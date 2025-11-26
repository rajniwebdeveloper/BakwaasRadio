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
import '../widgets/bakwaas_chrome.dart';
import '../app_data.dart';
import '../stations_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final List<Map<String, String>> _history = [];

  Widget _sectionHeader(String title, {VoidCallback? onSortToggle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        if (onSortToggle != null)
          IconButton(
              onPressed: onSortToggle,
              icon: const Icon(Icons.swap_vert, color: Colors.white70))
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white.withOpacity(0.04);

    return BakwaasScaffold(
      activeTab: 2,
      onMenuTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _buildMenuSheet(context),
      ),
      onExitTap: () => Navigator.of(context).maybePop(),
      bodyPadding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Library',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 18),

            // Filters-driven menu tiles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: ValueListenableBuilder<Set<String>>(
                valueListenable: LibraryData.filters,
                builder: (context, filters, _) {
                  if (filters.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('No sections enabled. Use menu → Filters to show.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    );
                  }

                  return Column(
                    children: [
                      if (filters.contains('liked'))
                        ValueListenableBuilder<List<Map<String, String>>>(
                          valueListenable: LikedSongsManager.liked,
                          builder: (context, likedList, __) {
                            return _buildTile(
                              context,
                              bg: bg,
                              icon: Icons.favorite_border,
                              title: 'Liked Songs',
                              count: likedList.length,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const LikedSongsPage())),
                            );
                          },
                        ),

                      if (filters.contains('albums'))
                        ValueListenableBuilder<List<Map<String, String>>>(
                          valueListenable: LibraryData.albums,
                          builder: (context, list, __) {
                            return _buildTile(
                              context,
                              bg: bg,
                              icon: Icons.album,
                              title: 'Albums',
                              count: list.length,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const AlbumsPage())),
                            );
                          },
                        ),

                      if (filters.contains('artists'))
                        ValueListenableBuilder<List<Map<String, String>>>(
                          valueListenable: LibraryData.artists,
                          builder: (context, list, __) {
                            return _buildTile(
                              context,
                              bg: bg,
                              icon: Icons.person,
                              title: 'Artists',
                              count: list.length,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const ArtistsPage())),
                            );
                          },
                        ),

                      if (filters.contains('downloads'))
                        ValueListenableBuilder<List<Map<String, String>>>(
                          valueListenable: LibraryData.downloads,
                          builder: (context, list, __) {
                            return _buildTile(
                              context,
                              bg: bg,
                              icon: Icons.download,
                              title: 'Downloads',
                              count: list.length,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const DownloadsPage())),
                            );
                          },
                        ),

                      if (filters.contains('playlists'))
                        _buildTile(
                          context,
                          bg: bg,
                          icon: Icons.queue_music,
                          title: 'Playlists',
                          count: AppData.playlists.length,
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const PlaylistsPage())),
                        ),
                      
                      if (filters.contains('stations'))
                        ValueListenableBuilder<List<dynamic>>(
                          valueListenable: LibraryData.stations,
                          builder: (context, list, __) {
                            return _buildTile(
                              context,
                              bg: bg,
                              icon: Icons.rss_feed,
                              title: 'Stations',
                              count: list.length,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const StationsPage())),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Recently Playing (simple placeholder)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Recently Playing'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: _history.isEmpty
                        ? Center(
                            child: Text('No recently played items',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7))),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _history.length,
                            itemBuilder: (context, idx) {
                              final s = _history[idx];
                              return SizedBox(
                                width: 220,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => SongPage(
                                                title: s['title'] ?? '',
                                                subtitle: s['subtitle'] ?? '',
                                                imageUrl: s['image'],
                                              ))),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BakwaasTheme.glassDecoration(
                                        radius: 14, opacity: 0.08),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                            radius: 36,
                                            backgroundImage: s['image'] != null && s['image']!.isNotEmpty
                                                ? NetworkImage(s['image']!)
                                                : const AssetImage('assets/logo.png') as ImageProvider,
                                            backgroundColor: Colors.white.withOpacity(0.04)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(s['title'] ?? '',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w700)),
                                              const SizedBox(height: 6),
                                              Text(s['subtitle'] ?? '',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: Colors.white.withOpacity(0.75)))
                                            ],
                                          ),
                                        )
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

            const SizedBox(height: 20),

            // Shuffle & play (disabled when no history)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _history.isNotEmpty
                    ? () {
                        _history.shuffle();
                        final s = _history.first;
                        final songMap = {
                          'title': s['title'] ?? '',
                          'subtitle': s['subtitle'] ?? '',
                          'image': s['image'] ?? ''
                        };
                        PlaybackManager.instance.play(songMap, duration: 191);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SongPage(
                                  title: songMap['title']!,
                                  subtitle: songMap['subtitle']!,
                                  imageUrl: songMap['image'],
                                  autoplay: true,
                                )));
                      }
                    : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.deepPurple.shade600, Colors.tealAccent]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.shuffle, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Shuffle & Play', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('Shuffle your library and start playing', style: TextStyle(color: Colors.black87, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.play_arrow, color: Colors.black87)
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context,
      {required Color bg, required IconData icon, required String title, required int count, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: bg,
        leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.black87)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [Padding(padding: const EdgeInsets.only(right: 8.0), child: Text('$count', style: const TextStyle(color: Colors.black87))), const Icon(Icons.chevron_right, color: Colors.black87)]),
        onTap: onTap,
      ),
    );
  }

  Widget _buildMenuSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.9), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.white),
            title: const Text('Liked', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LikedSongsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.white),
            title: const Text('Downloads', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DownloadsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.filter_list, color: Colors.white),
            title: const Text('Filters', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.of(context).pop();
              _showFiltersSheet(context);
            },
          ),
        ],
      ),
    );
  }

  void _showFiltersSheet(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) {
          final current = Set<String>.from(LibraryData.filters.value);
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.9), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Library Filters', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: current.contains('liked'),
                  title: const Text('Liked Songs', style: TextStyle(color: Colors.white)),
                  onChanged: (v) {
                    if (v == true) {
                      current.add('liked');
                    } else {
                      current.remove('liked');
                    }
                    LibraryData.filters.value = current;
                  },
                ),
                CheckboxListTile(
                  value: current.contains('albums'),
                  title: const Text('Albums', style: TextStyle(color: Colors.white)),
                  onChanged: (v) {
                    if (v == true) {
                      current.add('albums');
                    } else {
                      current.remove('albums');
                    }
                    LibraryData.filters.value = current;
                  },
                ),
                CheckboxListTile(
                  value: current.contains('artists'),
                  title: const Text('Artists', style: TextStyle(color: Colors.white)),
                  onChanged: (v) {
                    if (v == true) {
                      current.add('artists');
                    } else {
                      current.remove('artists');
                    }
                    LibraryData.filters.value = current;
                  },
                ),
                CheckboxListTile(
                  value: current.contains('downloads'),
                  title: const Text('Downloads', style: TextStyle(color: Colors.white)),
                  onChanged: (v) {
                    if (v == true) {
                      current.add('downloads');
                    } else {
                      current.remove('downloads');
                    }
                    LibraryData.filters.value = current;
                  },
                ),
                CheckboxListTile(
                  value: current.contains('playlists'),
                  title: const Text('Playlists', style: TextStyle(color: Colors.white)),
                  onChanged: (v) {
                    if (v == true) {
                      current.add('playlists');
                    } else {
                      current.remove('playlists');
                    }
                    LibraryData.filters.value = current;
                  },
                ),
                CheckboxListTile(
                  value: current.contains('stations'),
                  title: const Text('Stations', style: TextStyle(color: Colors.white)),
                  onChanged: (v) {
                    if (v == true) {
                      current.add('stations');
                    } else {
                      current.remove('stations');
                    }
                    LibraryData.filters.value = current;
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))
              ],
            ),
          );
        });
  }
}
