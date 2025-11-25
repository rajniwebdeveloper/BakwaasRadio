import 'package:flutter/material.dart';
import 'playlist_detail_page.dart';
import '../app_data.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  final bg = Colors.white;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  // keep track of the route animation listener so we can remove it
  ModalRoute<dynamic>? _route;
  AnimationStatusListener? _statusListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newRoute = ModalRoute.of(context);
    if (_route != newRoute) {
      // remove old listener
      if (_route != null &&
          _statusListener != null &&
          _route!.animation != null) {
        _route!.animation!.removeStatusListener(_statusListener!);
      }
      _route = newRoute;
      // add new listener
      if (_route != null && _route!.animation != null) {
        _statusListener = (status) {
          // when route becomes current again (after a pop), refresh
          if (_route!.isCurrent) {
            setState(() {});
          }
        };
        _route!.animation!.addStatusListener(_statusListener!);
      }
    }
  }

  @override
  void dispose() {
    if (_route != null &&
        _statusListener != null &&
        _route!.animation != null) {
      _route!.animation!.removeStatusListener(_statusListener!);
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlists = AppData.playlists;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 12.0),
                child: Row(children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Playlists',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: Icon(_showSearch ? Icons.close : Icons.search,
                          color: Colors.black87),
                      onPressed: () =>
                          setState(() => _showSearch = !_showSearch)),
                  // add new playlist
                  IconButton(
                      icon: const Icon(Icons.add, color: Colors.black87),
                      onPressed: () async {
                        final candidates = AppData.playlists
                            .expand((p) => (p['songs'] as List)
                                .cast<Map<String, String>>())
                            .toList();

                        await showDialog<void>(
                            context: context,
                            builder: (context) {
                              final TextEditingController nameCtrl =
                                  TextEditingController();
                              final selected =
                                  List<bool>.filled(candidates.length, false);
                              return StatefulBuilder(
                                  builder: (context, setStateDialog) {
                                return AlertDialog(
                                  backgroundColor: bg,
                                  title: const Text('New Playlist'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    height: 360,
                                    child: Column(
                                      children: [
                                        TextField(
                                          controller: nameCtrl,
                                          style: const TextStyle(
                                              color: Colors.black),
                                          decoration: const InputDecoration(
                                              hintText: 'Playlist name',
                                              hintStyle:
                                                  TextStyle(color: Colors.grey),
                                              border: OutlineInputBorder()),
                                        ),
                                        const SizedBox(height: 12),
                                        const Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text('Select songs',
                                                style: TextStyle(
                                                    color: Colors.black87))),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: candidates.length,
                                            itemBuilder: (ctx, idx) {
                                              final s = candidates[idx];
                                              return CheckboxListTile(
                                                activeColor: Colors.tealAccent,
                                                value: selected[idx],
                                                onChanged: (v) =>
                                                    setStateDialog(() =>
                                                        selected[idx] =
                                                            v ?? false),
                                                title: Text(s['title'] ?? '',
                                                    style: const TextStyle(
                                                        color: Colors.black)),
                                                subtitle: Text(
                                                    s['subtitle'] ?? '',
                                                    style: const TextStyle(
                                                        color: Colors.black87,
                                                        fontSize: 12)),
                                              );
                                            },
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Cancel')),
                                    ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.tealAccent),
                                        onPressed: () {
                                          final name = nameCtrl.text.trim();
                                          final selectedSongs =
                                              <Map<String, String>>[];
                                          for (var i = 0;
                                              i < candidates.length;
                                              i++) {
                                            if (selected[i]) {
                                              selectedSongs
                                                  .add(Map.from(candidates[i]));
                                            }
                                          }
                                          final newPlaylist = {
                                            'title': name.isEmpty
                                                ? 'New Playlist'
                                                : name,
                                            'image': selectedSongs.isNotEmpty
                                                ? selectedSongs
                                                        .first['image'] ??
                                                    ''
                                                : 'https://picsum.photos/200?image=70',
                                            'songs': selectedSongs
                                          };
                                          AppData.playlists
                                              .insert(0, newPlaylist);
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Create'))
                                  ],
                                );
                              });
                            });
                        setState(() {});
                      })
                ])),
            if (_showSearch)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.black),
                            decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Search playlists',
                                hintStyle: TextStyle(color: Colors.grey)))),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
                child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    itemCount: playlists.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final p = playlists[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 4),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          minVerticalPadding: 0,
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.grey.shade200,
                            ),
                            child: (p['image'] != null &&
                                    (p['image'] as String).isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(p['image'],
                                        fit: BoxFit.cover),
                                  )
                                : const Center(
                                    child: Icon(Icons.music_note,
                                        color: Colors.grey),
                                  ),
                          ),
                          title: Text(p['title'] ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${(p['songs'] as List).length} songs',
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 12)),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      PlaylistDetailPage(playlist: p))),
                          trailing: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            color: bg,
                            icon: const Icon(Icons.more_vert,
                                color: Colors.black87),
                            onSelected: (value) async {
                              if (value == 'open') {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        PlaylistDetailPage(playlist: p)));
                                return;
                              }
                              if (value == 'delete') {
                                final doDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                          backgroundColor: bg,
                                          title: const Text('Delete playlist'),
                                          content:
                                              Text('Delete "${p['title']}"?'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx)
                                                        .pop(false),
                                                child: const Text('Cancel')),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: const Text('Delete',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.redAccent))),
                                          ],
                                        ));
                                if (doDelete == true) {
                                  AppData.playlists.removeAt(i);
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Deleted ${p['title']}')));
                                }
                                return;
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 16),
                                  value: 'open',
                                  child: Text('Open',
                                      style: TextStyle(color: Colors.black))),
                              const PopupMenuItem(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 16),
                                  value: 'delete',
                                  child: Text('Delete',
                                      style: TextStyle(color: Colors.black))),
                            ],
                          ),
                        ),
                      );
                    }))
          ],
        ),
      ),
    );
  }
}
