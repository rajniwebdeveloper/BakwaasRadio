import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../app_data.dart';
import '../playback_manager.dart';
import '../config.dart';
import 'package:flutter/services.dart';

class BakwaasPalette {
  static const Color navy = Color(0xFF040812);
  static const Color deepPurple = Color(0xFF1A0B2E);
  static const Color neonGreen = Color(0xFF4EF2C4);
  static const Color aqua = Color(0xFF66F3FF);
  static const Color softYellow = Color(0xFFFFE082);
  static const Color pillDark = Color(0x80121B2F);
}

class BakwaasTheme {
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [BakwaasPalette.navy, BakwaasPalette.deepPurple],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient glowGradient = LinearGradient(
    colors: [Color(0xFF45F8C0), Color(0xFF0FB387)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardTint = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x1415324A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static TextStyle get headingStyle => const TextStyle(
        fontSize: 18,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      );

  static TextStyle get labelStyle => TextStyle(
        fontSize: 12,
        letterSpacing: 0.8,
      color: Colors.white.withAlpha((0.7 * 255).round()),
        fontWeight: FontWeight.w600,
      );

  static BoxDecoration glassDecoration(
      {double radius = 24, double opacity = 0.16}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withAlpha(((opacity + 0.05) * 255).round())),
      gradient: cardTint,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha((0.35 * 255).round()),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }
}

class BakwaasScaffold extends StatefulWidget {
  final Widget body;
  final EdgeInsetsGeometry bodyPadding;
  final String? backgroundImage;
  final int activeTab;
  final ValueChanged<int>? onNavTap;
  final VoidCallback? onMenuTap;
  final VoidCallback? onExitTap;
  final bool showBottomNav;

  const BakwaasScaffold({
    super.key,
    required this.body,
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
    this.backgroundImage,
    this.activeTab = 0,
    this.onNavTap,
    this.onMenuTap,
    this.onExitTap,
    this.showBottomNav = true,
  });

  @override
  State<BakwaasScaffold> createState() => _BakwaasScaffoldState();
}

class _BakwaasScaffoldState extends State<BakwaasScaffold> {
  String? _liveBackground;
  final GlobalKey _footerKey = GlobalKey();
  double _measuredFooterHeight = 0.0;
  bool _menuLocked = false;
  bool _exitLocked = false;

  @override
  void initState() {
    super.initState();
    PlaybackManager.instance.addListener(_playbackChanged);
    _updateFromPlayback();
  }

  void _playbackChanged() => _updateFromPlayback();

  void _updateFromPlayback() {
    final image = PlaybackManager.instance.currentSong?['image'];
    if (mounted) {
      setState(() {
        _liveBackground = (image != null && image.isNotEmpty) ? image : null;
      });
    }
  }

  @override
  void dispose() {
    PlaybackManager.instance.removeListener(_playbackChanged);
    super.dispose();
  }

  void _handleMenuTap() {
    if (_menuLocked) return;
    _menuLocked = true;
    try {
      widget.onMenuTap?.call();
    } catch (_) {}
    // unlock after short delay to allow modal to open without double-invoke
    Future.delayed(const Duration(milliseconds: 600), () {
      _menuLocked = false;
    });
  }

  void _handleExitTap() {
    if (_exitLocked) return;
    _exitLocked = true;
    try {
      widget.onExitTap?.call();
    } catch (_) {}
    Future.delayed(const Duration(milliseconds: 400), () {
      _exitLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBg = widget.backgroundImage ?? _liveBackground;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration:
            const BoxDecoration(gradient: BakwaasTheme.backgroundGradient),
        child: Stack(
          children: [
            if (effectiveBg != null && effectiveBg.isNotEmpty)
              Positioned.fill(
                  child: _BlurredAlbumBackground(imageUrl: effectiveBg)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withAlpha((0.6 * 255).round()), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
            ),
            // Top area (header + content). Footer (mini-player + nav) is
            // rendered as an overlay positioned at the bottom so it stays
            // fixed and doesn't change the height of the main content.
            SafeArea(
              top: true,
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  BakwaasTopBar(
                    onMenuTap: () => _handleMenuTap(),
                    onExitTap: () => _handleExitTap(),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Padding(
                      // Ensure callers' bottom padding does not accidentally
                      // reserve extra space for the footer. We clamp the
                      // final bottom padding to at most the provided value,
                      // and add extra space equal to footer height when
                      // the footer is shown so content won't be obscured.
                      padding: _effectiveBodyPadding(widget.bodyPadding, widget.showBottomNav),
                      child: widget.body,
                    ),
                  ),
                ],
              ),
            ),
            // Fixed footer overlay
            if (widget.showBottomNav)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Wrap footer in a keyed container so we can measure its
                      // height at runtime and reserve exact padding for content.
                      Container(
                        key: _footerKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Show mini-player on non-player tabs so users have
                            // quick access to current playback. When the Player
                            // tab (index 1) is active the full player UI is
                            // shown there, so hide the mini-player to avoid a
                            // duplicate control surface.
                            if (widget.activeTab != 1) _MiniPlayer(),
                            BakwaasBottomNav(
                              activeIndex: widget.activeTab,
                              onTap: widget.onNavTap ?? (index) {
                                if (index == widget.activeTab) return;
                                Navigator.of(context).popUntil((r) => r.isFirst);
                                AppData.rootTab.value = index.clamp(0, 2);
                                return;
                              },
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                // (debug overlay removed) footer measurement not shown in UI
          ],
        ),
      ),
    );
  }

  EdgeInsets _effectiveBodyPadding(EdgeInsetsGeometry paddingGeom, bool showFooter) {
    // Footer height should scale down on small screens to avoid
    // overflowing content. Use up to a capped size but prefer the
    // measured footer height when available to avoid under/over-reserving.
    final screenH = MediaQuery.of(context).size.height;
    final maxFooter = 140.0;
    final estimatedFooter = 48.0 /* mini player */ + 72.0 /* bottom nav */ + 12.0;
    double footerHeight;
    if (_measuredFooterHeight > 0.0) {
      footerHeight = _measuredFooterHeight;
    } else {
      footerHeight = math.min(maxFooter, math.max(estimatedFooter, screenH * 0.20));
    }
    final p = paddingGeom is EdgeInsets ? paddingGeom : const EdgeInsets.fromLTRB(20, 0, 20, 16);
    // Reserve the larger of current bottom padding or the footer height so
    // we don't double-count and cause overflow.
    final bottom = showFooter ? math.max(p.bottom, footerHeight) : p.bottom;
    // After layout, attempt to measure footer so future builds reserve exact space.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureFooter());
    return p.copyWith(bottom: bottom);
  }

  void _measureFooter() {
    try {
      final ctx = _footerKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final h = box.size.height + MediaQuery.of(context).viewPadding.bottom;
      if (h > 0 && (h - _measuredFooterHeight).abs() > 1.0) {
        setState(() {
          _measuredFooterHeight = h;
        });
      }
    } catch (_) {}
  }
}

  class _MiniPlayer extends StatefulWidget {
    @override
    State<_MiniPlayer> createState() => _MiniPlayerState();
  }

  class _MiniPlayerState extends State<_MiniPlayer> {
    static const MethodChannel _volumeChannel = MethodChannel('com.bakwaas.fm/volume');
    @override
    void initState() {
      super.initState();
      PlaybackManager.instance.addListener(_onPlaybackChanged);
    }

    void _onPlaybackChanged() => setState(() {});

    @override
    void dispose() {
      PlaybackManager.instance.removeListener(_onPlaybackChanged);
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      final mgr = PlaybackManager.instance;
      final song = mgr.currentSong;
      if (song == null) return const SizedBox.shrink();

      final title = song['title'] ?? 'Unknown';
      final subtitle = song['subtitle'] ?? '';

      return GestureDetector(
        onTap: () {
          // Switch to the Player tab (index 1) instead of opening a separate player route
          try {
            Navigator.of(context).popUntil((r) => r.isFirst);
          } catch (_) {}
          AppData.rootTab.value = 1;
        },
          child: Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.04 * 255).round()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha((0.04 * 255).round())),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                        children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white12,
                      image: (song['image'] != null && song['image']!.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(song['image']!), fit: BoxFit.cover)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withAlpha((0.7 * 255).round()), fontSize: 12)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(mgr.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white),
                        onPressed: () => mgr.toggle(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Colors.white70),
                        onPressed: () async {
                          // show volume dialog
                          double vol = 0.5;
                          try {
                            final cur = await _volumeChannel.invokeMethod('getVolume');
                            vol = (cur is double) ? cur : (cur is num ? cur.toDouble() : vol);
                          } catch (_) {}
                            if (!mounted) return;

                            // ignore: use_build_context_synchronously
                            showDialog(
                              context: AppData.navigatorKey.currentContext!,
                              builder: (ctx) {
                                return AlertDialog(
                                  backgroundColor: Colors.black87,
                                  content: StatefulBuilder(
                                    builder: (c, setState) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Device volume', style: TextStyle(color: Colors.white)),
                                          const SizedBox(height: 12),
                                          Slider(
                                            value: vol.clamp(0.0, 1.0),
                                            onChanged: (v) async {
                                              setState(() => vol = v);
                                              try {
                                                await _volumeChannel.invokeMethod('setVolume', v);
                                              } catch (_) {}
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: const Text('Close', style: TextStyle(color: Colors.white)))
                                  ],
                                );
                              });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: mgr.progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withAlpha((0.06 * 255).round()),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                minHeight: 3,
              ),
            ],
          ),
        ),
      );
    }
  }

class BakwaasTopBar extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onExitTap;

  const BakwaasTopBar({super.key, this.onMenuTap, this.onExitTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlassButton(
                  icon: Icons.menu,
                  onTap: onMenuTap,
                ),
                _GlassButton(
                  icon: Icons.exit_to_app,
                  onTap: onExitTap,
                ),
              ],
            ),
            // show app logo and name (with package id subtitle) centered
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(AppInfo.logoAsset, width: 26, height: 26),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppInfo.appName, style: BakwaasTheme.headingStyle),
                    const Text(AppInfo.packageName,
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GlassButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
        child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withAlpha((0.06 * 255).round()),
          border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class BakwaasBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int>? onTap;

  const BakwaasBottomNav({super.key, required this.activeIndex, this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      const _NavItem(Icons.radio, 'Stations'),
      const _NavItem(Icons.play_arrow, 'Player'),
      const _NavItem(Icons.favorite, 'Favorites'),
    ];
    return SafeArea(
      top: false,
        child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        // reduce vertical padding to make the nav a bit shorter
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.04 * 255).round()),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withAlpha((0.06 * 255).round())),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha((0.5 * 255).round()),
                blurRadius: 28,
                offset: const Offset(0, -6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isActive = index == activeIndex;
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onTap?.call(index),
                  borderRadius: BorderRadius.circular(24),
                  splashColor: Colors.white24,
                  child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Render a flat icon (no circular background). Active state
                        // shows a subtle underline to indicate selection.
                        Padding(
                          // slightly smaller vertical padding for a more compact look
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Icon(item.icon,
                              color: isActive
                                ? BakwaasPalette.softYellow
                                : Colors.white.withAlpha((0.88 * 255).round()),
                              size: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: Colors.white.withAlpha(((isActive ? 0.95 : 0.7) * 255).round()),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // small indicator
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isActive ? 20 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isActive
                                ? BakwaasPalette.softYellow
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _BlurredAlbumBackground extends StatelessWidget {
  final String imageUrl;

  const _BlurredAlbumBackground({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(color: Colors.black.withAlpha((0.3 * 255).round())),
          )
        ],
      ),
    );
  }
}
