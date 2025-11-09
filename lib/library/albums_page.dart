import 'package:flutter/material.dart';
import 'song_page.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  final bg = Colors.white;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final albums = [
      {
        'title': 'Once Upon A Time In Mumbaai',
        'image': 'https://picsum.photos/200?image=11'
      },
      {'title': 'Romantic Hits', 'image': 'https://picsum.photos/200?image=12'},
    ];
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Albums',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: Icon(_showSearch ? Icons.close : Icons.search,
                          color: Colors.black87),
                      onPressed: () =>
                          setState(() => _showSearch = !_showSearch)),
                ],
              ),
            ),
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
                          hintText: 'Search albums',
                          hintStyle: TextStyle(color: Colors.grey)),
                    )),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                itemCount: albums.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final a = albums[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.grey.shade200,
                              image: DecorationImage(
                                  image: NetworkImage(a['image']!),
                                  fit: BoxFit.cover))),
                      title: Text(a['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SongPage(
                              title: a['title'] ?? '',
                              subtitle: 'Various Artists',
                              imageUrl: a['image']))),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
