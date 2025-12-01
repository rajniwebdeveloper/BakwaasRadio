import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
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
    // variants first (web, emulator, simulator) and then fall back to
    // public hosts in the order requested by the user.
    final List<String> localCandidates = kIsWeb
      ? ['http://localhost:3222', 'http://127.0.0.1:3222']
      : ['http://localhost:3222', 'http://127.0.0.1:3222', 'http://10.0.2.2:3222'];

    // Public hosts (probing order): primary, local DNS, radio fallback, beta
    final List<String> publicCandidates = [
      'https://bakwaasfm.in',
      'https://local.bakwaasfm.in',
      'https://radio.rajnikantmahato.me',
      'https://beta.bakwaasfm.in',
    ];

    final probeTimeout = timeout.inSeconds < 3 ? const Duration(seconds: 3) : timeout;

    // Helper to probe a single URL's /api/health endpoint
    Future<bool> probe(String base) async {
      try {
        final uri = Uri.parse('$base/api/health');
        final resp = await http.get(uri).timeout(probeTimeout);
        return resp.statusCode == 200;
      } catch (e) {
        return false;
      }
    }

    // Try locals first (in user-requested order: localhost first)
    for (final candidate in localCandidates) {
      final ok = await probe(candidate);
      if (ok) {
        _cachedBaseUrl = candidate;
        debugPrint('AppConfig.resolveApiBaseUrl -> using $candidate (local)');
        return _cachedBaseUrl!;
      }
    }

    // Try public hosts in the specified order
    for (final candidate in publicCandidates) {
      final ok = await probe(candidate);
      if (ok) {
        _cachedBaseUrl = candidate;
        debugPrint('AppConfig.resolveApiBaseUrl -> using $candidate (public)');
        return _cachedBaseUrl!;
      }
    }

    // If none responded, fall back to the primary public host as a last resort
    _cachedBaseUrl = publicCandidates.isNotEmpty ? publicCandidates.first : 'https://radio.rajnikantmahato.me';
    debugPrint('AppConfig.resolveApiBaseUrl -> falling back to $_cachedBaseUrl');
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
  static String get apiBaseUrlSync => _cachedBaseUrl ?? 'https://bakwaasfm.in';
}

/// Basic app identity constants used in UI (app name, package id, logo asset).
class AppInfo {
  static const String appName = 'Bakwaas FM';
  // package identifier (application id)
  static const String packageName = 'com.bakwaas.fm';
  static const String logoAsset = 'assets/logo.png';

  // App version and build code (keep in sync with pubspec.yaml `version:`)
  // Example pubspec version: 6.0.0+6 -> version: "6.0.0", build: 6
  static const String version = '6.0.0';
  static const int buildNumber = 6;
}
