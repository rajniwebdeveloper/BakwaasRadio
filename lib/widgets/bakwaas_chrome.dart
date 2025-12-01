import 'dart:ui';

import 'package:flutter/material.dart';
import '../app_data.dart';
import '../playback_manager.dart';
import '../config.dart';

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
        color: Colors.white.withOpacity(0.7),
        fontWeight: FontWeight.w600,
      );

  static BoxDecoration glassDecoration(
      {double radius = 24, double opacity = 0.16}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withOpacity(opacity + 0.05)),
      gradient: cardTint,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
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
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
            ),
            SafeArea(
              // ensure the body doesn't extend under system/navigation bars
              // so bottom controls (and hit testing) work correctly on open
              bottom: true,
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  BakwaasTopBar(
                    onMenuTap: widget.onMenuTap,
                    onExitTap: widget.onExitTap,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Padding(
                      padding: widget.bodyPadding,
                      child: widget.body,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.showBottomNav)
              Align(
                alignment: Alignment.bottomCenter,
                child: BakwaasBottomNav(
                  activeIndex: widget.activeTab,
                  onTap: widget.onNavTap ?? (index) {
                    // Default navigation when parent doesn't provide a handler.
                    // Instead of pushing new pages for primary tabs, update
                    // the global `AppData.rootTab` and return to the root route
                    // so the main HomePage can show the selected tab. This
                    // prevents stacking multiple `BakwaasScaffold`s and
                    // duplicate bottom nav bars.
                    if (index == widget.activeTab) return;
                    // Pop back to root then set the global tab value so the
                    // HomePage (if present) will switch its content.
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    AppData.rootTab.value = index.clamp(0, 2);
                    return;
                  },
                ),
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
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
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
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        // reduce vertical padding to make the nav a bit shorter
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
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
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Render a flat icon (no circular background). Active state
                        // shows a subtle underline to indicate selection.
                        Padding(
                          // slightly smaller vertical padding for a more compact look
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Icon(item.icon,
                              color: isActive
                                  ? BakwaasPalette.softYellow
                                  : Colors.white.withOpacity(0.88),
                              size: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: Colors.white.withOpacity(isActive ? 0.95 : 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
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
            child: Container(color: Colors.black.withOpacity(0.3)),
          )
        ],
      ),
    );
  }
}
