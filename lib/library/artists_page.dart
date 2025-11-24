import 'package:flutter/material.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
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
    final artists = [
      {'name': 'Vishal Mishra'},
      {'name': 'Armaan Malik'},
    ];
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
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Artists',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: Icon(_showSearch ? Icons.close : Icons.search,
                          color: Colors.white70),
                      onPressed: () =>
                          setState(() => _showSearch = !_showSearch))
                ])),
            const SizedBox(height: 8),
            if (_showSearch)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(children: [
                    const Icon(Icons.search, color: Colors.white54),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search artists',
                          hintStyle: TextStyle(color: Colors.white54)),
                    )),
                  ]),
                ),
              ),
            Expanded(
                child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    itemCount: artists.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final a = artists[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(a['name'] ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      );
                    }))
          ],
        ),
      ),
    );
  }
}
