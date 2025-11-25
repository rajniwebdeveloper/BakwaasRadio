import 'package:flutter/material.dart';
import '../playback_manager.dart';
import 'song_page.dart';

class PlaylistDetailPage extends StatelessWidget {
  final Map<String, dynamic> playlist;
  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    final songs = (playlist['songs'] as List).cast<Map<String, String>>();
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(playlist['title'] ?? ''),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const Divider(color: Color.fromARGB(255, 236, 236, 236)),
        itemBuilder: (context, index) {
          final s = songs[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: (s['image'] != null && s['image']!.isNotEmpty)
                  ? NetworkImage(s['image']!)
                  : null,
              child: (s['image'] == null || s['image']!.isEmpty)
                  ? const Icon(Icons.music_note, color: Colors.black54)
                  : null,
            ),
            title: Text(s['title'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(s['subtitle'] ?? '',
                style: const TextStyle(color: Colors.black87)),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle, color: Colors.black),
              onPressed: () {
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
                        autoplay: true)));
              },
            ),
            onTap: () {
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
                      autoplay: true)));
            },
          );
        },
      ),
    );
  }
}
