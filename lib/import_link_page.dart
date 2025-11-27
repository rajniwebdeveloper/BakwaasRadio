import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';

import 'playback_manager.dart';
import 'app_data.dart';

// ImportLinkPage uses backend-provided labels/features via `AppData.uiConfig`.

class ImportLinkPage extends StatefulWidget {
  final List<String> urls;
  const ImportLinkPage({super.key, required this.urls});

  @override
  State<ImportLinkPage> createState() => _ImportLinkPageState();
}

class _ImportLinkPageState extends State<ImportLinkPage> {
  bool _importing = true;
  bool _probing = false;
  List<_UrlInfo> _items = [];
  Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    // show importing animation for 2 seconds then probe
    Timer(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _probing = true;
      });
      await _probeAll();
      if (!mounted) return;
      setState(() => _probing = false);
    });
  }

  Future<void> _probeAll() async {
    final results = <_UrlInfo>[];
    for (final u in widget.urls) {
      try {
        final head = await http.head(Uri.parse(u)).timeout(const Duration(seconds: 5));
        final mime = head.headers['content-type'] ?? 'unknown';
        final length = head.headers['content-length'];
        results.add(_UrlInfo(url: u, contentType: mime, contentLength: length));
      } catch (_) {
        results.add(_UrlInfo(url: u));
      }
    }
    setState(() {
      _items = results;
      _selected = Set<int>.from(List.generate(_items.length, (i) => i));
    });
  }

  void _playSelected(int index) {
    final item = _items[index];
    PlaybackManager.instance.play({'url': item.url, 'title': item.title});
    // open full player to show playback UI
    Navigator.of(context).pop();
  }



  void _downloadSelected() async {
    final toDownload = _selected.toList()..sort();
    if (toDownload.isEmpty) return;
    // open each URL in external browser so the system handles download
    for (final i in toDownload) {
      final u = _items[i].url;
      try {
        await launchUrlString(u);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: AppData.uiConfig,
      builder: (ctx, ui, _) {
        final labels = ui['labels'] as Map<String, dynamic>?;
        final feats = ui['features'] as Map<String, dynamic>?;
        final importTitle = (labels != null && labels.containsKey('import_title')) ? (labels['import_title'] as String) : 'Import link';
        final playLabel = (labels != null && labels.containsKey('import_play')) ? (labels['import_play'] as String) : 'Play Now';
        final downloadLabel = (labels != null && labels.containsKey('import_download')) ? (labels['import_download'] as String) : 'Download Now';
        final enableDownloads = feats != null ? (feats['enable_downloads'] as bool? ?? false) : false;

        return ValueListenableBuilder<bool>(
          valueListenable: AppData.isLoggedIn,
          builder: (ctx2, loggedIn, __2) {
            final showDownloads = enableDownloads && loggedIn;
            return Scaffold(
              appBar: AppBar(
                title: Text(importTitle),
                backgroundColor: Colors.black87,
              ),
              backgroundColor: Colors.black,
              body: _importing
                  ? _buildImporting()
                  : _probing
                      ? _buildProbing()
                      : _buildResultBody(playLabel, downloadLabel, showDownloads),
            );
          },
        );
      },
    );
  }

  Widget _buildImporting() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        const CircularProgressIndicator(color: Colors.green),
        const SizedBox(height: 12),
        const Text('Importing shared link...', style: TextStyle(color: Colors.white70)),
      ]),
    );
  }

  Widget _buildProbing() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        const CircularProgressIndicator(color: Colors.green),
        const SizedBox(height: 12),
        const Text('Fetching info from network...', style: TextStyle(color: Colors.white70)),
      ]),
    );
  }

  Widget _buildResultBody(String playLabel, String downloadLabel, bool enableDownloads) {
    if (_items.isEmpty) return const Center(child: Text('No valid links found', style: TextStyle(color: Colors.white70)));

    return Column(children: [
      Expanded(
        child: ListView.builder(
          itemCount: _items.length,
          itemBuilder: (ctx, i) {
            final it = _items[i];
            final selected = _selected.contains(i);
            return CheckboxListTile(
              value: selected,
              onChanged: (v) {
                setState(() {
                  if (v == true) _selected.add(i); else _selected.remove(i);
                });
              },
              title: Text(it.title, style: const TextStyle(color: Colors.white)),
              subtitle: Text(it.subtitle, style: const TextStyle(color: Colors.white70)),
            );
          },
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  final sel = _selected.toList();
                  if (sel.length == 1) {
                    _playSelected(sel.first);
                  } else if (sel.length > 1) {
                    final map = sel.map((i) => MapEntry(i, _items[i])).toList();
                    final idx = await showModalBottomSheet<int>(
                        context: context,
                        builder: (_) {
                          return SafeArea(
                            child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: map.length,
                                itemBuilder: (ctx, j) {
                                  final e = map[j];
                                  return ListTile(
                                    title: Text(e.value.title, style: const TextStyle(color: Colors.white)),
                                    subtitle: Text(e.value.subtitle, style: const TextStyle(color: Colors.white70)),
                                    onTap: () => Navigator.of(ctx).pop(e.key),
                                  );
                                }),
                          );
                        });
                    if (idx != null) _playSelected(idx);
                  } else {
                    _playSelected(0);
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(playLabel),
              ),
            ),
            const SizedBox(width: 12),
            if (enableDownloads)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  onPressed: _downloadSelected,
                  icon: const Icon(Icons.download),
                  label: Text(downloadLabel),
                ),
              ),
          ]),
        ),
      )
    ]);
  }
}

class _UrlInfo {
  final String url;
  final String? contentType;
  final String? contentLength;
  _UrlInfo({required this.url, this.contentType, this.contentLength});

  String get title {
    try {
      final uri = Uri.parse(url);
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.host;
    } catch (_) {
      return url;
    }
  }

  String get subtitle {
    final parts = <String>[];
    if (contentType != null) parts.add(contentType!);
    if (contentLength != null) parts.add('${contentLength} bytes');
    return parts.isEmpty ? url : parts.join(' • ');
  }
}
