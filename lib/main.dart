import 'package:bakwaas_fm/api_service.dart';
import 'package:bakwaas_fm/models/station.dart';
import 'package:flutter/material.dart';
import 'library/song_page.dart';
import 'playback_manager.dart';
import 'library/library_page.dart';
import 'app_data.dart';
import 'ui_helpers.dart';
import 'profile_page.dart';
import 'library/playlists_page.dart';
import 'library/playlist_detail_page.dart';

// Demo/sample songs removed. App will show live data or empty states.

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bakwaas FM',
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.grey.shade100,
        primaryColor: Colors.tealAccent,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(), // Keep the top bar
            const SizedBox(height: 12), // Spacing after top bar
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TabsRow(), // Move TabsRow here
                    const SizedBox(height: 20), // Add space after the tabs
                    Section(
                        title: 'Stations',
                        itemCount: 6,
                        cardType: CardType.station,
                        onViewAll: () {
                          // Navigator.of(context).push(MaterialPageRoute(
                          //     builder: (_) => AllSongsPage(
                          //         title: 'Recently Played',
                          //         songs: sampleSongs)));
                        }),
                    const SizedBox(height: 20),
                    // Stations section remains; demo sections removed.
                    Section(
                        title: 'Your Playlists',
                        // use actual data length so empty lists are handled safely
                        itemCount: AppData.playlists.length,
                        cardType: CardType.playlist,
                        onViewAll: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const PlaylistsPage()));
                        }),
                    const SizedBox(height: 120), // leave room for mini-player
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomWithMiniPlayer(),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // smaller logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.music_note, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Bakwaas FM',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProfilePage()));
            },
            icon: const Icon(Icons.settings_outlined),
            color: Colors.black87,
          ),
        ],
      ),
    );
  }
}

class TabsRow extends StatelessWidget {
  const TabsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: const [
          ToggleButton(label: 'Music', selected: true),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.grey.shade200 : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: selected ? Colors.black : Colors.black87)),
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
          height: cardType == CardType.album ? 130 : 150,
          child: cardType == CardType.station
              ? FutureBuilder<List<Station>>(
                  future: ApiService.getStations(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final stations = snapshot.data!;
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: stations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final station = stations[index];
                          return SizedBox(
                            width: 120,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => SongPage(
                                        station: station,
                                        title: station.name,
                                        subtitle: station.description ?? '',
                                        imageUrl: station.profilepic,
                                        autoplay: true)));
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 80,
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                      image: (station.profilepic != null && station.profilepic!.isNotEmpty)
                                          ? DecorationImage(
                                              image: NetworkImage(station.profilepic!),
                                              fit: BoxFit.cover)
                                          : null,
                                    ),
                                    child: (station.profilepic == null || station.profilepic!.isEmpty)
                                        ? const Center(
                                            child: Icon(Icons.album,
                                                size: 36,
                                                color: Colors.black54))
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(station.description ?? '',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    } else if (snapshot.hasError) {
                      return const Center(child: Text('Failed to load data'));
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (cardType == CardType.album) {
                      // No demo sample songs — show simple placeholders.
                      final title = 'Item ${index + 1}';
                      final subtitle = '';
                      final image = null;
                      return SizedBox(
                        width: 120,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => SongPage(
                                    title: title,
                                    subtitle: subtitle,
                                    imageUrl: image,
                                    autoplay: false)));
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 80,
                                width: 120,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                    child: Icon(Icons.album,
                                        size: 36, color: Colors.black54)),
                              ),
                              const SizedBox(height: 6),
                              Text(title,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(subtitle,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    } else {
                      // Handle empty playlists gracefully
                      if (AppData.playlists.isEmpty) {
                        return SizedBox(
                          width: 120,
                          child: Center(
                              child: Text('No playlists yet',
                                  style:
                                      TextStyle(color: Colors.black54))),
                        );
                      }
                      final playlist = AppData.playlists[
                          index % AppData.playlists.length];
                      final title = playlist['title'] ?? '';
                      final imageUrl = playlist['image'];
                      return SizedBox(
                        width: 120,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      PlaylistDetailPage(playlist: playlist))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 90,
                                width: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: (imageUrl != null &&
                                          (imageUrl as String).isNotEmpty)
                                      ? DecorationImage(
                                          image: NetworkImage(imageUrl),
                                          fit: BoxFit.cover)
                                      : null,
                                  gradient: imageUrl == null ||
                                          (imageUrl as String).isEmpty
                                      ? LinearGradient(colors: [
                                          Colors.teal.shade300,
                                          Colors.purple.shade300
                                        ], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                      : null,
                                ),
                                child: (imageUrl == null ||
                                        (imageUrl as String).isEmpty)
                                    ? const Center(
                                        child: Icon(Icons.playlist_play,
                                            size: 36, color: Colors.white))
                                    : null,
                              ),
                              const SizedBox(height: 6),
                              Text(title,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
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
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: onViewAll ?? () {},
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('View All >',
              style: TextStyle(color: Colors.black87, fontSize: 12)),
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
    final bg = Colors.white;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: songs.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Color.fromARGB(255, 236, 236, 236)),
        itemBuilder: (context, idx) {
          final s = songs[idx];
          return ListTile(
            leading: CircleAvatar(
                backgroundImage: NetworkImage(s['image'] ?? ''),
                backgroundColor: Colors.grey.shade200),
            title: Text(s['title'] ?? ''),
            subtitle: Text(s['subtitle'] ?? ''),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SongPage(
                    title: s['title'] ?? '',
                    subtitle: s['subtitle'] ?? '',
                    imageUrl: s['image']))),
          );
        },
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
    final bg = Colors.white;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, title: const Text('Trending Now')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.78,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8),
          itemCount: songs.length,
          itemBuilder: (context, i) {
            final s = songs[i % songs.length];
            return InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SongPage(
                      title: s['title'] ?? '',
                      subtitle: s['subtitle'] ?? '',
                      imageUrl: s['image'],
                      autoplay: true))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                              image: NetworkImage(s['image'] ?? ''),
                              fit: BoxFit.cover),
                          color: Colors.grey.shade800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(s['title'] ?? '',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class BottomWithMiniPlayer extends StatefulWidget {
  const BottomWithMiniPlayer({super.key});

  @override
  State<BottomWithMiniPlayer> createState() => _BottomWithMiniPlayerState();
}

class _BottomWithMiniPlayerState extends State<BottomWithMiniPlayer> {
  @override
  void initState() {
    super.initState();
    PlaybackManager.instance.addListener(_onPlaybackChanged);
    // initialize lastSong from manager if available
  }

  @override
  void dispose() {
    PlaybackManager.instance.removeListener(_onPlaybackChanged);
    super.dispose();
  }

  void _onPlaybackChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mgr = PlaybackManager.instance;
    final song = mgr.currentSong;
    final isPlaying = mgr.isPlaying;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Only a slider is shown per request. If no song is loaded,
            // the slider is disabled.
            Slider.adaptive(
              value: (mgr.progress >= 0.0 && mgr.progress <= 1.0)
                  ? mgr.progress
                  : 0.0,
              onChanged: song != null
                  ? (v) {
                      mgr.seek(v);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
