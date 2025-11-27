import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart';

import 'import_link_page.dart';

/// Listens for incoming deep-links and share intents and navigates to
/// ImportLinkPage when a URL or shared text is received.
class DeepLinkHandler {
  DeepLinkHandler._private();
  static final DeepLinkHandler instance = DeepLinkHandler._private();

  StreamSubscription? _sub;
  StreamSubscription? _shareSubs;

  void startListening(BuildContext context) {
    // On web the `uriLinkStream` implementation is not supported (can't change
    // the page URL without a reload) so avoid subscribing to the stream there.
    if (!kIsWeb) {
      // Listen for app link URIs (cold start is handled elsewhere via initialUri)
      _sub ??= uriLinkStream.listen((uri) {
        if (uri == null) return;
        _handleIncoming(context, uri.toString());
      }, onError: (err) {
        // ignore errors
      });

      // Also handle initial uri if app opened via link (native platforms)
      getInitialUri().then((uri) {
        if (uri != null) _handleIncoming(context, uri.toString());
      }).catchError((_) {});
    } else {
      // For web, check current page URL once (e.g. when the app is opened with
      // a query/path) and navigate if it contains a link. Avoid trying to
      // subscribe to streams which are unimplemented on web.
      try {
        final current = Uri.base.toString();
        if (current.isNotEmpty) {
          final urls = _extractUrls(current);
          if (urls.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ImportLinkPage(urls: urls),
                ));
              } catch (_) {}
            });
          }
        }
      } catch (_) {}
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _shareSubs?.cancel();
    _shareSubs = null;
  }

  void _handleIncoming(BuildContext context, String text) {
    // Extract URLs from text and navigate to import page
    final urls = _extractUrls(text);
    if (urls.isEmpty) return;

    // If multiple urls, pass list; otherwise single
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImportLinkPage(urls: urls),
    ));
  }

  static final _urlRegex = RegExp(
      r"((https?:\\/\\/)?([\w-]+\\.)+[\w-]{2,}(\\/[\w\-._~:\/?#\[\]@!$&'()*+,;=%]*)?)",
      caseSensitive: false);

  List<String> _extractUrls(String text) {
    final matches = _urlRegex.allMatches(text);
    final found = <String>{};
    for (final m in matches) {
      var url = m.group(1) ?? '';
      if (url.isEmpty) continue;
      // If scheme missing, prepend https:// for easier probing
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      // Only keep meaningful links
      found.add(url);
    }
    return found.toList();
  }
}
