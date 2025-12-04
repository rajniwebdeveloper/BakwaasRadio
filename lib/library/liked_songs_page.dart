import 'package:flutter/material.dart';
import '../app_data.dart';
import '../playback_manager.dart';
import 'liked_songs_manager.dart';

// Embedded content widget used by HomePage and the full Liked page.
class LikedSongsContent extends StatefulWidget {
  const LikedSongsContent({super.key});

  @override
  State<LikedSongsContent> createState() => _LikedSongsContentState();
}

class _LikedSongsContentState extends State<LikedSongsContent> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  final Set<String> _playButtonCooldown = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('Liked Songs',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              TextButton(
                  onPressed: () => LikedSongsManager.clear(),
                  child:
                      const Text('Clear', style: TextStyle(color: Colors.tealAccent))),
              IconButton(
                  icon: Icon(_showSearch ? Icons.close : Icons.search,
                      color: Colors.white70),
                  onPressed: () => setState(() => _showSearch = !_showSearch)),
            ],
          ),
        ),
        if (_showSearch)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Container(
              decoration:
                  BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search liked songs',
                        hintStyle: TextStyle(color: Colors.white54)),
                  )),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        ValueListenableBuilder<List<Map<String, String>>>(
          valueListenable: LikedSongsManager.liked,
          builder: (context, liked, _) {
            if (liked.isEmpty) {
              return const Expanded(
                  child: Center(
                      child: Text('No liked songs',
                          style: TextStyle(color: Colors.white70))));
            }
            return Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                itemCount: liked.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final s = liked[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 0),
                      leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.grey.shade800,
                              image: s['image'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(s['image']!),
                                      fit: BoxFit.cover)
                                  : null)),
                      title: Text(s['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(s['subtitle'] ?? '',
                          style: const TextStyle(color: Colors.white70)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow,
                                  color: Colors.white70),
                              onPressed: (_playButtonCooldown.contains(s['url'] ?? '') || (s['url'] ?? '').isEmpty)
                                  ? null
                                  : () async {
                                      final url = s['url'] ?? '';
                                      final song = <String, String>{
                                        'title': s['title'] ?? '',
                                        'subtitle': s['subtitle'] ?? '',
                                        'image': s['image'] ?? '',
                                        'url': url,
                                      };
                                      _playButtonCooldown.add(url);
                                      try {
                                        await PlaybackManager.instance.play(song);
                                      } catch (_) {}
                                      Future.delayed(const Duration(milliseconds: 700), () {
                                        if (mounted) setState(() => _playButtonCooldown.remove(url));
                                      });
                                      setState(() {});
                                    },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.white70),
                              onPressed: () => LikedSongsManager.remove(s),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await AppData.openPlayerWith(song: s);
                        },
                      ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// Full page wrapper (keeps backward compatibility)
class LikedSongsPage extends StatelessWidget {
  const LikedSongsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF2B2F35),
      body: SafeArea(child: LikedSongsContent()),
    );
  }
}
