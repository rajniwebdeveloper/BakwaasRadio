import 'package:flutter/material.dart';
import 'song_page.dart';
import 'liked_songs_manager.dart';

class LikedSongsPage extends StatefulWidget {
  const LikedSongsPage({super.key});

  @override
  State<LikedSongsPage> createState() => _LikedSongsPageState();
}

class _LikedSongsPageState extends State<LikedSongsPage> {
  final bg = const Color(0xFF2B2F35);
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Liked Songs',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold))),
                  TextButton(
                      onPressed: () => LikedSongsManager.clear(),
                      child: const Text('Clear',
                          style: TextStyle(color: Colors.tealAccent))),
                  IconButton(
                      icon: Icon(_showSearch ? Icons.close : Icons.search,
                          color: Colors.white70),
                      onPressed: () =>
                          setState(() => _showSearch = !_showSearch)),
                ],
              ),
            ),
            if (_showSearch)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8)),
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
                                  image: DecorationImage(
                                      image: NetworkImage(s['image']!),
                                      fit: BoxFit.cover))),
                          title: Text(s['title'] ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(s['subtitle'] ?? '',
                              style: const TextStyle(color: Colors.white70)),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                icon: const Icon(Icons.play_arrow,
                                    color: Colors.white70),
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => SongPage(
                                            title: s['title'] ?? '',
                                            subtitle: s['subtitle'] ?? '',
                                            imageUrl: s['image'])))),
                            IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.white70),
                                onPressed: () => LikedSongsManager.remove(s)),
                          ]),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => SongPage(
                                      title: s['title'] ?? '',
                                      subtitle: s['subtitle'] ?? '',
                                      imageUrl: s['image']))),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
