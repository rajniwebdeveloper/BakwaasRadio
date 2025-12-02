import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'import_link_page.dart';
import 'app_data.dart';

/// Listens for incoming deep-links and navigates to `ImportLinkPage` when a
/// URL or shared text is received. This implementation uses the newer
/// `app_links` API (uriLinkStream / getInitialUri) available in v7.
class DeepLinkHandler {
  DeepLinkHandler._private();
  static final DeepLinkHandler instance = DeepLinkHandler._private();

  StreamSubscription? _uriSub;
  final AppLinks _appLinks = AppLinks();

  void startListening() {
    if (kIsWeb) {
      // On web, check current page URL once and navigate if it contains a link.
      try {
        final current = Uri.base.toString();
        if (current.isNotEmpty) {
          final urls = _extractUrls(current);
          if (urls.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                final nav = AppData.navigatorKey.currentState;
                if (nav != null) {
                  nav.push(MaterialPageRoute(builder: (_) => ImportLinkPage(urls: urls)));
                }
              } catch (_) {}
            });
          }
        }
      } catch (_) {}
      return;
    }

    // Listen to incoming URI link stream
    _uriSub ??= _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri == null) return;
      try {
        _handleIncoming(uri.toString());
      } catch (_) {}
    }, onError: (_) {});

    // Note: older helper methods for fetching an initial link were removed
    // from the `app_links` v7 API. We rely on the `uriLinkStream` to emit
    // incoming links; on platforms where an initial link is required we can
    // implement a platform-specific probe later.
  }

  void dispose() {
    _uriSub?.cancel();
    _uriSub = null;
  }

  void _handleIncoming(String text) {
    final urls = _extractUrls(text);
    if (urls.isEmpty) return;
    // Use the global navigator key so we don't rely on a possibly-stale
    // BuildContext captured when listeners were registered.
    final nav = AppData.navigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(builder: (_) => ImportLinkPage(urls: urls)));
  }

  static final _urlRegex = RegExp(
      r"((https?:\/\/)?([\w-]+\.)+[\w-]{2,}(\/[-\w._~:\/?#\[\]@!$&'()*+,;=%]*)?)",
      caseSensitive: false);

  List<String> _extractUrls(String text) {
    final matches = _urlRegex.allMatches(text);
    final found = <String>{};
    for (final m in matches) {
      var url = m.group(1) ?? '';
      if (url.isEmpty) continue;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      found.add(url);
    }
    return found.toList();
  }
}
