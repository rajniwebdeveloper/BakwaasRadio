import 'package:flutter/material.dart';
import 'app_data.dart';

Future<void> showAddToPlaylistSheet(
    BuildContext context, Map<String, String> song) {
  final bg = const Color(0xFF2B2F35);
  return showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        final lists = AppData.playlists;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, color: Colors.white12),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Add to playlist',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: lists.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12),
                  itemBuilder: (context, i) {
                    final p = lists[i];
                    return ListTile(
                      leading: CircleAvatar(
                          backgroundImage: p['image'] != null
                              ? NetworkImage(p['image'])
                              : null,
                          backgroundColor: Colors.grey.shade800),
                      title: Text(p['title'] ?? '',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${(p['songs'] as List).length} songs',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      onTap: () {
                        (p['songs'] as List).add(Map.from(song));
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Added to ${p['title']}')));
                      },
                    );
                  },
                ),
              )
            ],
          ),
        );
      });
}
