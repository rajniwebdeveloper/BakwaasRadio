import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// AppConfig provides a resolver for the API base URL.
/// It attempts to reach a local backend first (useful during development)
/// and falls back to the public host `https://radio.rajnikantmahato.me`.
class AppConfig {
  static String? _cachedBaseUrl;
  static String? _forcedBaseUrl;

  /// Resolve the API base URL by probing a local backend first.
  /// On Android emulator the host should be `http://10.0.2.2:3222`.
  /// On other platforms it will try `http://localhost:3222`.
  /// If the probe fails, it falls back to `https://radio.rajnikantmahato.me`.
  static Future<String> resolveApiBaseUrl({Duration timeout = const Duration(seconds: 3)}) async {
    // If a forced base is set (useful for debugging / browser testing), return it.
    if (_forcedBaseUrl != null && _forcedBaseUrl!.isNotEmpty) return _forcedBaseUrl!;
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    // Prefer a local backend during development. Try multiple local host
    // variants so simulators, emulators and web can connect more reliably.
    // Avoid using `dart:io` so this file works on web builds too.
    final List<String> candidates = kIsWeb
      ? ['http://localhost:3222', 'http://127.0.0.1:3222']
      : [ 'http://127.0.0.1:3222', 'http://localhost:3222'];
    const fallback = 'https://radio.rajnikantmahato.me';
    final probeTimeout = timeout.inSeconds < 5 ? const Duration(seconds: 5) : timeout;

    for (final local in candidates) {
      try {
        final uri = Uri.parse('$local/api/health');
        final resp = await http.get(uri).timeout(probeTimeout);
        if (resp.statusCode == 200) {
          _cachedBaseUrl = local;
          return _cachedBaseUrl!;
        }
      } catch (_) {
        // try next candidate
      }
    }

    _cachedBaseUrl = fallback;
    return _cachedBaseUrl!;
  }

  /// Force the API base URL for debugging (e.g. `http://localhost:3222`).
  /// Pass `null` to clear the forced value and fall back to probing.
  static void forceBaseUrl(String? url) {
    _forcedBaseUrl = url;
    if (url != null && url.isNotEmpty) {
      _cachedBaseUrl = url;
    } else {
      _cachedBaseUrl = null;
    }
  }

  /// Returns the last resolved base URL synchronously if available, or the
  /// public fallback. Prefer `resolveApiBaseUrl()` for reliable results.
  static String get apiBaseUrlSync => _cachedBaseUrl ?? 'https://radio.rajnikantmahato.me';
}
