import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/station.dart';
import 'config.dart';

class ApiService {
  // Internal cached base URL for this runtime session. Use AppConfig.resolveApiBaseUrl
  // to initialize it. ApiService will call the resolver on-demand.
  static String? _cachedBaseUrl;

  static Future<String> _baseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    _cachedBaseUrl = await AppConfig.resolveApiBaseUrl();
    return _cachedBaseUrl!;
  }

  /// Fetch stations and decode into `Station` objects.
  static Future<List<Station>> getStations() async {
    final base = await _baseUrl();
    final uri = Uri.parse('$base/api/stations');

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      return data.map((e) => Station.fromJson(e as Map<String, dynamic>)).toList();
    }

    throw Exception('Failed to load stations: ${response.statusCode}');
  }

  /// Fetch streams (returns dynamic JSON). Endpoint: /api/streams
  static Future<dynamic> getStreams() async {
    final base = await _baseUrl();
    final uri = Uri.parse('$base/api/streams');
    final response = await http.get(uri);
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load streams: ${response.statusCode}');
  }

  /// Fetch radio info. Endpoint: /api/radio
  static Future<dynamic> getRadioInfo() async {
    final base = await _baseUrl();
    final uri = Uri.parse('$base/api/radio');
    final response = await http.get(uri);
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load radio info: ${response.statusCode}');
  }

  /// Fetch API root data. Endpoint: /api
  static Future<dynamic> getApiRoot() async {
    final base = await _baseUrl();
    final uri = Uri.parse('$base/api');
    final response = await http.get(uri);
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load api root: ${response.statusCode}');
  }

  /// Run search on the backend. Endpoint: /api/search?q=...
  static Future<dynamic> search(String q) async {
    final base = await _baseUrl();
    final uri = Uri.parse('$base/api/search?q=${Uri.encodeQueryComponent(q)}');
    final response = await http.get(uri);
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Search failed: ${response.statusCode}');
  }

  /// Proxy to player routes. Path should start with '/' if needed.
  /// Example: proxyPlayer('/play?url=...') -> GET {base}/player/play?url=...
  static Future<dynamic> proxyPlayer(String path) async {
    final base = await _baseUrl();
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base/player$normalized');
    final response = await http.get(uri);
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Player proxy failed: ${response.statusCode}');
  }

  /// Health check. Endpoint: /api/health
  static Future<bool> healthCheck() async {
    final base = await _baseUrl();
    final uri = Uri.parse('$base/api/health');
    try {
      final response = await http.get(uri).timeout(Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
