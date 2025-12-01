import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class CacheHelper {
  static const _stationsFile = 'cached_stations.json';

  /// Return the app cache directory.
  static Future<Directory> _cacheDir() async {
    final d = await getTemporaryDirectory();
    return d;
  }

  /// Save raw stations JSON to cache.
  static Future<void> saveStationsJson(String jsonStr) async {
    try {
      final dir = await _cacheDir();
      final f = File('${dir.path}/$_stationsFile');
      await f.writeAsString(jsonStr);
    } catch (e) {
      if (kDebugMode) debugPrint('saveStationsJson error: $e');
    }
  }

  /// Load cached stations JSON, or null if not present.
  static Future<String?> loadStationsJson() async {
    try {
      final dir = await _cacheDir();
      final f = File('${dir.path}/$_stationsFile');
      if (await f.exists()) return await f.readAsString();
    } catch (e) {
      if (kDebugMode) debugPrint('loadStationsJson error: $e');
    }
    return null;
  }

  /// Generate a filesystem-safe filename for a URL using base64Url encoding.
  static String _fileNameForUrl(String url) {
    final enc = base64Url.encode(utf8.encode(url));
    return enc;
  }

  /// Download an image and store it in cache. Returns local file path or null on failure.
  static Future<String?> cacheImage(String url) async {
    if (url.isEmpty) return null;
    try {
      final dir = await _cacheDir();
      final name = _fileNameForUrl(url);
      final file = File('${dir.path}/$name');
      if (await file.exists()) return file.path;
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(resp.bodyBytes);
        return file.path;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('cacheImage error: $e');
    }
    return null;
  }

  /// Return the local cached file path for a URL if present, otherwise null.
  static Future<String?> localImagePath(String url) async {
    try {
      if (url.isEmpty) return null;
      final dir = await _cacheDir();
      final name = _fileNameForUrl(url);
      final file = File('${dir.path}/$name');
      if (await file.exists()) return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('localImagePath error: $e');
    }
    return null;
  }
}
