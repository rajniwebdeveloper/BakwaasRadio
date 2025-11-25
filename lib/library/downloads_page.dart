import 'package:flutter/material.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
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
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('Downloads',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
              IconButton(
                  icon: Icon(_showSearch ? Icons.close : Icons.search,
                      color: Colors.black87),
                  onPressed: () => setState(() => _showSearch = !_showSearch))
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
                      hintText: 'Search downloads',
                      hintStyle: TextStyle(color: Colors.grey)),
                )),
              ]),
            ),
          ),
        const Expanded(
            child: Center(
                child:
                    Text('No downloads', style: TextStyle(color: Colors.grey))))
      ])),
    );
  }
}
