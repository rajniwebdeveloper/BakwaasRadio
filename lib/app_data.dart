import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const _kAuthTokenKey = 'auth_token';
const _kAuthTokenExpiresKey = 'auth_token_expires';
const _kAuthUserKey = 'auth_user_json';

class AppData {
  // Demo playlists removed. Keep an empty list so UI can handle "no data".
  static final List<Map<String, dynamic>> playlists = [];
  // Global root tab notifier so independent pages can request switching
  // the main bottom navigation (0: Home, 1: Liked, 2: Library).
  static final ValueNotifier<int> rootTab = ValueNotifier<int>(0);

  // UI labels/config coming from backend (optional). This map may contain
  // nested `labels` and `features` keys. Initialize with safe defaults so
  // UI can use these synchronously before the network call completes.
  static final ValueNotifier<Map<String, dynamic>> uiConfig = ValueNotifier<Map<String, dynamic>>(
    <String, dynamic>{
      'labels': {
        'menu_profile': 'Profile',
        'menu_downloads': 'Downloads',
        'menu_filters': 'Filters',
        'menu_now_playing': 'Now Playing',
        'menu_sleep_timer': 'Sleep Timer',
        'filters_title': 'Library Filters',
        'filter_liked': 'Liked Songs',
        'filter_albums': 'Albums',
        'filter_artists': 'Artists',
        'filter_downloads': 'Downloads',
        'filter_playlists': 'Playlists',
        'filter_stations': 'Stations',
        'filter_recent': 'Recently Played',
        'filters_clear': 'Clear',
        'filters_done': 'Done',
        'import_title': 'Import link',
        'import_play': 'Play Now',
        'import_download': 'Download Now',
      },
      'features': {
        // Backend can set this to true to expose download-related flows.
        // Default false to be safe for App Store compliance.
        'enable_downloads': false,
        // Default to false: hide login/signup buttons until backend enables them
        'show_login_button': false,
      }
    }
  );

  /// Convenience accessor for UI labels. Returns `key` from `uiConfig['labels']`
  /// or `fallback` if not found.
  static String label(String key, {String? fallback}) {
    final labels = uiConfig.value['labels'] as Map<String, dynamic>?;
    if (labels != null && labels.containsKey(key)) return labels[key] as String;
    return fallback ?? key;
  }

  /// Check feature flag presence in `uiConfig['features']`.
  static bool featureEnabled(String key) {
    final feats = uiConfig.value['features'] as Map<String, dynamic>?;
    if (feats == null) return false;
    final val = feats[key];
    if (val is bool) return val;
    return false;
  }

  /// Logged-in state. UI can listen to this to conditionally expose
  /// features like downloads which should require authentication.
  static final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);

  /// Optional current user data (empty when not logged in).
  static final ValueNotifier<Map<String, dynamic>> currentUser = ValueNotifier<Map<String, dynamic>>(<String, dynamic>{});

  /// Load persisted auth token and user (if any) from `SharedPreferences`.
  /// If a valid token is found, sets `isLoggedIn` and populates `currentUser`.
  static Future<void> loadAuthFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kAuthTokenKey);
      final expires = prefs.getString(_kAuthTokenExpiresKey);
      final userJson = prefs.getString(_kAuthUserKey);
      if (token != null) {
        currentUser.value = <String, dynamic>{'token': token};
        if (userJson != null) {
          try {
            final decoded = userJson.isNotEmpty ? (jsonDecode(userJson) as Map<String, dynamic>) : <String, dynamic>{};
            currentUser.value.addAll(decoded);
          } catch (_) {}
        }
        // Validate expiry if present
        if (expires != null && expires.isNotEmpty) {
          final dt = DateTime.tryParse(expires);
          if (dt != null && dt.isAfter(DateTime.now().toUtc())) {
            isLoggedIn.value = true;
          } else {
            // expired
            currentUser.value = <String, dynamic>{};
            await clearAuthPrefs();
          }
        } else {
          // no expiry recorded -> consider logged out for safety
          currentUser.value = <String, dynamic>{};
          await clearAuthPrefs();
        }
      }
    } catch (e) {
      // ignore errors reading prefs
    }
  }

  /// Persist current auth token, expiry and user to prefs.
  static Future<void> saveAuthToPrefs({required String token, String? tokenExpiresAt, Map<String, dynamic>? user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAuthTokenKey, token);
    if (tokenExpiresAt != null) await prefs.setString(_kAuthTokenExpiresKey, tokenExpiresAt);
    if (user != null) {
      try {
        await prefs.setString(_kAuthUserKey, jsonEncode(user));
      } catch (_) {}
    }
  }

  /// Clear persisted auth info
  static Future<void> clearAuthPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthTokenKey);
    await prefs.remove(_kAuthTokenExpiresKey);
    await prefs.remove(_kAuthUserKey);
  }
}
