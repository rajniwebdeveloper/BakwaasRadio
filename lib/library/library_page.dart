import 'package:flutter/material.dart';

import 'downloads_page.dart';
import 'library_data.dart';
import 'liked_songs_manager.dart';
import '../app_data.dart';
import '../models/station.dart';
import '../playback_manager.dart';
import '../widgets/bakwaas_chrome.dart';

// LibraryPage: a focused, simple library overview. The clickable
// section tiles were intentionally removed from the main content —
// users should open the top-left menu → Filters to enable sections.
class LibraryPage extends StatefulWidget {
  final bool useScaffold;
  const LibraryPage({super.key, this.useScaffold = true});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final List<Map<String, String>> _history = [];

  @override
  void initState() {
    super.initState();
    // Load library stations on first build so Library shows live data.
    LibraryData.load().catchError((e) {
      // ignore: avoid_print
      print('LibraryPage.initState: failed to load stations: $e');
    });
    // Keep recent history in sync with PlaybackManager persisted history.
    PlaybackManager.instance.loadPersisted();
    PlaybackManager.instance.addListener(_playbackListenerForHistory);
  }

  void _playbackListenerForHistory() {
    setState(() {
      _history.clear();
      for (final s in PlaybackManager.instance.history) {
        _history.add({'title': s['title'] ?? '', 'subtitle': s['subtitle'] ?? '', 'image': s['image'] ?? ''});
      }
    });
  }

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
    final content = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Library',
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 18),

          // Hint pointing to Filters menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                'Use the top-left menu → Filters to show library sections (Liked, Albums, Stations, etc.).',
                style: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round())),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Recently Playing (visible only when 'recent' filter enabled)
          ValueListenableBuilder<Set<String>>(
            valueListenable: LibraryData.filters,
            builder: (context, filters, _) {
              if (!filters.contains('recent')) return const SizedBox.shrink();
              return Padding(
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
                                    color: Colors.white.withAlpha((0.7 * 255).round()))),
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
                                    onTap: () async {
                                      final songMap = <String, String>{
                                        'title': s['title'] ?? '',
                                        'subtitle': s['subtitle'] ?? '',
                                        'image': s['image'] ?? '',
                                      };
                                      await AppData.openPlayerWith(song: songMap);
                                    },
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
                                              backgroundColor: Colors.white.withAlpha((0.04 * 255).round())),
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
                                                      color: Colors.white.withAlpha((0.75 * 255).round())))
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
              );
            },
          ),

          const SizedBox(height: 20),

          // Stations (live data from backend) — shown only if filters include 'stations'
          ValueListenableBuilder<Set<String>>(
            valueListenable: LibraryData.filters,
            builder: (context, filters, _) {
              if (!filters.contains('stations')) return const SizedBox.shrink();
              return ValueListenableBuilder<List<Station>>(
                valueListenable: LibraryData.stations,
                builder: (context, stations, __) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Stations'),
                      const SizedBox(height: 12),
                      if (LibraryData.stationsError.value != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withAlpha((0.12 * 255).round()),
                              borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(LibraryData.stationsError.value ?? '',
                                      style: TextStyle(color: Colors.redAccent.withAlpha((0.9 * 255).round())))),
                                TextButton(
                                    onPressed: () => LibraryData.load(forceRefresh: true),
                                    child: const Text('Retry'))
                              ],
                            ),
                          ),
                        ),
                      if (stations.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                const Text('No stations available', style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 8),
                                ElevatedButton(onPressed: () => LibraryData.load(forceRefresh: true), child: const Text('Reload'))
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          children: stations.map((s) => _buildStationTile(context, s)).toList(),
                        )
                    ],
                  );
                },
              );
            },
          ),

          // Shuffle & play (disabled when no history)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
                      onTap: _history.isNotEmpty
                  ? () async {
                      _history.shuffle();
                      final s = _history.first;
                      final songMap = <String, String>{
                        'title': s['title'] ?? '',
                        'subtitle': s['subtitle'] ?? '',
                        'image': s['image'] ?? ''
                      };
                      await AppData.openPlayerWith(song: songMap);
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
    );

    if (widget.useScaffold) {
      return BakwaasScaffold(
        activeTab: 2,
        showBottomNav: false,
        onMenuTap: () => showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _buildMenuSheet(context),
        ),
        onExitTap: () => Navigator.of(context).maybePop(),
        bodyPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        body: content,
      );
    }

    return content;
  }

  Widget _buildMenuSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withAlpha((0.9 * 255).round()), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.white),
            title: const Text('Liked', style: TextStyle(color: Colors.white)),
            onTap: () {
              // Close the menu sheet and request the app to switch to the
              // Liked tab so the bottom nav remains visible and behavior is
              // consistent across places.
              Navigator.of(context).pop();
              // If this LibraryPage was shown as a standalone page, also
              // pop back to the root so the main HomePage is visible.
              Navigator.of(context).popUntil((r) => r.isFirst);
              AppData.rootTab.value = 1;
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
            decoration: BoxDecoration(color: Colors.black.withAlpha((0.9 * 255).round()), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
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
                  value: current.contains('recent'),
                  title: const Text('Recently Playing', style: TextStyle(color: Colors.white)),
                  onChanged: (v) {
                    if (v == true) {
                      current.add('recent');
                    } else {
                      current.remove('recent');
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

  Widget _buildStationTile(BuildContext context, Station s) {
    final url = s.playerUrl ?? s.streamURL ?? s.mp3Url ?? '';
    final image = s.profilepic ?? s.banner ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
            onTap: url.isNotEmpty
            ? () async {
                await AppData.openPlayerWith(station: s);
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BakwaasTheme.glassDecoration(radius: 12, opacity: 0.06),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: image.isNotEmpty ? NetworkImage(image) : const AssetImage('assets/logo.png') as ImageProvider,
                backgroundColor: Colors.white.withAlpha((0.04 * 255).round()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(s.description ?? '', style: TextStyle(color: Colors.white.withAlpha((0.75 * 255).round()), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: url.isNotEmpty
                    ? () async {
                        await AppData.openPlayerWith(station: s);
                      }
                    : null,
                icon: Icon(url.isNotEmpty ? Icons.play_arrow : Icons.block, color: url.isNotEmpty ? Colors.tealAccent : Colors.white30),
              )
              ,
              IconButton(
                onPressed: () {
                  final songMap = {'title': s.name, 'subtitle': s.description ?? '', 'image': image, 'url': url};
                  if (LikedSongsManager.contains(songMap)) {
                    LikedSongsManager.remove(songMap);
                  } else {
                    LikedSongsManager.add(songMap);
                  }
                },
                icon: Icon(
                  LikedSongsManager.contains({'title': s.name, 'subtitle': s.description ?? ''})
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: Colors.pinkAccent,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    PlaybackManager.instance.removeListener(_playbackListenerForHistory);
    super.dispose();
  }
}
