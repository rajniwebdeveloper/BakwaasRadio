import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

/// AppConfig provides a resolver for the API base URL.
/// It attempts to reach a local backend first (useful during development)
/// and falls back to the public host `https://radio.rajnikantmahato.me`.
class AppConfig {
  static String? _cachedBaseUrl;

  /// Resolve the API base URL by probing a local backend first.
  /// On Android emulator the host should be `http://10.0.2.2:3222`.
  /// On other platforms it will try `http://localhost:3222`.
  /// If the probe fails, it falls back to `https://radio.rajnikantmahato.me`.
  static Future<String> resolveApiBaseUrl({Duration timeout = const Duration(seconds: 3)}) async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;

    final local = Platform.isAndroid ? 'http://10.0.2.2:3222' : 'http://localhost:3222';
    final fallback = 'https://radio.rajnikantmahato.me';

    try {
      final uri = Uri.parse('$local/api/health');
      final resp = await http.get(uri).timeout(timeout);
      if (resp.statusCode == 200) {
        _cachedBaseUrl = local;
        return _cachedBaseUrl!;
      }
    } catch (_) {
      // ignore - we'll fall back to public host
    }

    _cachedBaseUrl = fallback;
    return _cachedBaseUrl!;
  }

  /// Returns the last resolved base URL synchronously if available, or the
  /// public fallback. Prefer `resolveApiBaseUrl()` for reliable results.
  static String get apiBaseUrlSync => _cachedBaseUrl ?? 'https://radio.rajnikantmahato.me';
}
