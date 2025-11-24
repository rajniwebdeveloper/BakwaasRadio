import 'dart:math' as math;
import 'package:bakwaas_fm/api_service.dart';
import 'package:bakwaas_fm/models/station.dart';
import 'package:flutter/material.dart';
import 'library/song_page.dart';
import 'playback_manager.dart';
import 'library/library_page.dart';
import 'app_data.dart';
import 'profile_page.dart';
import 'library/playlists_page.dart';
import 'library/playlist_detail_page.dart';
import 'widgets/bakwaas_chrome.dart';
import 'widgets/orbital_ring.dart';

// Demo/sample songs removed. App will show live data or empty states.

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bakwaas FM',
      theme: base.copyWith(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: base.colorScheme.copyWith(
          primary: BakwaasPalette.neonGreen,
          secondary: BakwaasPalette.aqua,
          background: BakwaasPalette.navy,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final PlaybackManager _playback = PlaybackManager.instance;
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat();
    _playback.addListener(_handlePlayback);
  }

  @override
  void dispose() {
    _ringController.dispose();
    _playback.removeListener(_handlePlayback);
    super.dispose();
  }

  void _handlePlayback() => setState(() {});

  Map<String, String>? get _heroSong =>
      _playback.currentSong ?? _playback.lastSong;

  void _openFullPlayer() {
    final song = _heroSong ??
        {
          'title': 'Dhaka FM',
          'subtitle': 'Live Radio',
          'image': '',
          'url': '',
        };
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SongPage(
        title: song['title'] ?? 'Dhaka FM',
        subtitle: song['subtitle'] ?? 'Live Radio',
        imageUrl: song['image'],
        autoplay: _playback.isPlaying,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final heroSong = _heroSong ??
        {
          'title': 'Dhaka FM',
          'subtitle': 'Live Radio',
          'image': '',
        };
    final cover = heroSong['image'];

    return BakwaasScaffold(
      backgroundImage: cover,
      activeTab: 0,
      onMenuTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LibraryPage())),
      onExitTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ProfilePage()));
      },
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
        children: [
          _buildHeroSection(heroSong),
          const SizedBox(height: 24),
          const TabsRow(),
          const SizedBox(height: 20),
          Section(
            title: 'Stations',
            itemCount: 6,
            cardType: CardType.station,
            onViewAll: () {},
          ),
          const SizedBox(height: 20),
          Section(
            title: 'Your Playlists',
            itemCount: AppData.playlists.length,
            cardType: CardType.playlist,
            onViewAll: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlaylistsPage()));
            },
          ),
        ],
      ),
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
        _buildProgress(),
        const SizedBox(height: 20),
        _buildVolumeAndBanner(song),
      ],
    );
  }

  Widget _buildOrbit(String? imageUrl) {
    const double size = 220.0;
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
                          : null,
                      color: Colors.black,
                    ),
                    child: (imageUrl == null || imageUrl.isEmpty)
                        ? const Icon(Icons.radio, color: Colors.white, size: 44)
                        : null,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
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
          Text(song['title'] ?? 'Dhaka FM',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(
              song['subtitle']?.isNotEmpty == true
                  ? song['subtitle']!
                  : 'Live Radio',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.78))),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            onPressed: _openFullPlayer,
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
                        .withOpacity(_playback.isPlaying ? 0.45 : 0.2),
                    blurRadius: _playback.isPlaying ? 28 : 16,
                    spreadRadius: _playback.isPlaying ? 6 : 2,
                  ),
                ],
              ),
              child: Icon(
                _playback.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
          IconButton(
            onPressed: _openFullPlayer,
            icon: const Icon(Icons.skip_next, color: Colors.white70),
            iconSize: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final progress = _playback.progress.clamp(0.0, 1.0);
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: BakwaasPalette.neonGreen,
            inactiveTrackColor: Colors.white.withOpacity(0.15),
            thumbColor: Colors.white,
            overlayColor: BakwaasPalette.neonGreen.withOpacity(0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: progress,
            onChanged:
                _playback.currentSong != null ? (v) => _playback.seek(v) : null,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_playback.isPlaying ? 'Now Playing…' : "Let's Play…",
                style: TextStyle(color: Colors.white.withOpacity(0.72))),
            Text(_formatTime(progress * _playback.durationSeconds),
                style: TextStyle(color: Colors.white.withOpacity(0.72))),
          ],
        ),
      ],
    );
  }

  Widget _buildVolumeAndBanner(Map<String, String> song) {
    final volume = _playback.volume;
    return Column(
      children: [
        GestureDetector(
          onPanUpdate: (details) {
            final updated =
                (_playback.volume - details.delta.dy / 300).clamp(0.0, 1.0);
            _playback.setVolume(updated);
          },
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 96 + (volume * 18),
                    height: 96 + (volume * 18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      boxShadow: [
                        BoxShadow(
                          color: BakwaasPalette.neonGreen
                              .withOpacity(0.15 + volume * 0.25),
                          blurRadius: 26 + volume * 18,
                          spreadRadius: 7 + volume * 5,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 98,
                    height: 98,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: BakwaasTheme.glowGradient,
                      boxShadow: [
                        BoxShadow(
                          color: BakwaasPalette.neonGreen
                              .withOpacity(0.25 + volume * 0.25),
                          blurRadius: 18 + volume * 12,
                          spreadRadius: 2 + volume * 3,
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: (volume - 0.5) * math.pi,
                      child: const Icon(Icons.volume_up,
                          color: Colors.white, size: 36),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withOpacity(0.2),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withOpacity(0.12),
                ),
                child: Slider(
                  value: volume,
                  onChanged: (v) => _playback.setVolume(v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildLetsPlayBanner(song),
      ],
    );
  }

  Widget _buildLetsPlayBanner(Map<String, String> song) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Let's Play",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 4),
                Text(song['title'] ?? 'Dhaka FM',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openFullPlayer,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playback.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
              ),
            ),
          )
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final total = seconds.round();
    final minutes = (total ~/ 60).toString();
    final secs = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }
}

class TabsRow extends StatelessWidget {
  const TabsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: const [
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
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withOpacity(selected ? 0.3 : 0.12)),
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
              ? FutureBuilder<List<Station>>(
                  future: ApiService.getStations(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final stations = snapshot.data!;
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
                                                Colors.white.withOpacity(0.05),
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
                                                Colors.white.withOpacity(0.7),
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                          child: Text('Failed to load data',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7))));
                    }
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
                                        color: Colors.white.withOpacity(0.6),
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
                                      color: Colors.white.withOpacity(0.6)))),
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
                                        color: Colors.white.withOpacity(0.65),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
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
      onMenuTap: () => Navigator.of(context).maybePop(),
      onExitTap: () => Navigator.of(context).maybePop(),
      bodyPadding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
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
                          backgroundImage: s['image'] != null
                              ? NetworkImage(s['image']!)
                              : null,
                          backgroundColor: Colors.white.withOpacity(0.08),
                        ),
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
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12)),
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
      onMenuTap: () => Navigator.of(context).maybePop(),
      onExitTap: () => Navigator.of(context).maybePop(),
      bodyPadding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
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
                                color: Colors.white.withOpacity(0.04),
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
