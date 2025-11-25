import 'package:flutter/material.dart';

class LibraryData {
  static final ValueNotifier<List<Map<String, String>>> albums = ValueNotifier([
    {
      'title': 'Once Upon A Time In Mumbaai',
      'image': 'https://picsum.photos/200?image=11'
    },
    {'title': 'Romantic Hits', 'image': 'https://picsum.photos/200?image=12'},
  ]);

  static final ValueNotifier<List<Map<String, String>>> artists =
      ValueNotifier([
    {'name': 'Vishal Mishra'},
    {'name': 'Armaan Malik'},
  ]);

  static final ValueNotifier<List<Map<String, String>>> downloads =
      ValueNotifier(<Map<String, String>>[]);

  static final ValueNotifier<List<Map<String, String>>> playlists =
      ValueNotifier([
    {'title': 'Starred Songs', 'image': 'https://picsum.photos/200?image=15'},
    {'title': '#JioSaavnReplay', 'image': 'https://picsum.photos/200?image=16'},
  ]);

  // Global filter set for Library page (keys: liked, albums, artists, downloads, playlists)
  static final ValueNotifier<Set<String>> filters =
      ValueNotifier<Set<String>>(<String>{});
}
