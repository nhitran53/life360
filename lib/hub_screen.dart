import 'dart:math' as math;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// HUB SCREEN — the main menu after the home screen
// ---------------------------------------------------------------------------

/// One tile on the hub.
class _HubItem {
  const _HubItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> colors;
}

const _hubItems = [
  _HubItem(
    emoji: '📊',
    title: 'My Stats',
    subtitle: 'Sleep, steps & sweat',
    colors: [Color(0xFF00F5A0), Color(0xFF00B4D8)], // mint → aqua
  ),
  _HubItem(
    emoji: '👯',
    title: "Friends' Stats",
    subtitle: "See what your crew's up to",
    colors: [Color(0xFFFF9A44), Color(0xFFFF3CAC)], // orange → pink
  ),
  _HubItem(
    emoji: '🏆',
    title: 'Leaderboard',
    subtitle: "Who's on top this week?",
    colors: [Color(0xFFFFE53B), Color(0xFFFF6B00)], // yellow → orange
  ),
];

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> with TickerProviderStateMixin {
  /// Loops forever: background rotation + cards bobbing.
  late final AnimationController _bg =
  AnimationController(vsync: this, duration: const Duration(seconds: 12))
    ..repeat();

  /// Plays once on open: header pops, cards slide in one by one.
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();

  @override
  void dispose() {
    _bg.dispose();
    _intro.dispose();
    super.dispose();
  }

  void _open(_HubItem item) {
    // TODO: swap ComingSoonPage for the real screens when they're built.
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => ComingSoonPage(
          title: item.title,
          emoji: item.emoji,
          colors: item.colors,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerPop = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bg,
        builder: (context, child) {
          final angle = _bg.value * 2 * math.pi;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(math.cos(angle), math.sin(angle)),
                end: Alignment(-math.cos(angle), -math.sin(angle)),
                colors: const [
                  Color(0xFFFF3CAC), // hot pink
                  Color(0xFF784BA0), // purple
                  Color(0xFF2B86C5), // electric blue
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TopBar(),
                const SizedBox(height: 20),

                // HEADER
                ScaleTransition(scale: headerPop, child: const _Header()),
                const SizedBox(height: 32),

                // CARDS — staggered slide-in, then gentle bobbing
                for (var i = 0; i < _hubItems.length; i++) ...[
                  _staggeredCard(i),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _staggeredCard(int i) {
    final start = 0.25 + i * 0.15;
    final slideIn = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, math.min(start + 0.45, 1.0),
          curve: Curves.easeOutBack),
    );

    return FadeTransition(
      opacity: slideIn,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.6), end: Offset.zero)
            .animate(slideIn),
        child: AnimatedBuilder(
          animation: _bg,
          builder: (context, child) {
            // Each card bobs slightly out of sync with the others.
            final bob =
                math.sin((_bg.value * 3 + i / 3) * 2 * math.pi) * 4;
            return Transform.translate(offset: Offset(0, bob), child: child);
          },
          child: _HubCard(
            item: _hubItems[i],
            onTap: () => _open(_hubItems[i]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TOP BAR + HEADER
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.2),
          shape: const CircleBorder(),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Friend 360',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 48), // balances the back button
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'THE HUB',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFFE53B),
            height: 1.0,
            letterSpacing: 3,
            shadows: [
              const Shadow(
                color: Color(0xFFFF6B00),
                offset: Offset(5, 5),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(9, 9),
              ),
              Shadow(
                color: const Color(0xFFFFE53B).withValues(alpha: 0.8),
                blurRadius: 26,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            ),
            child: const Text(
              'Where to, champ? 👀',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// HUB CARD — big squishy gradient tile
// ---------------------------------------------------------------------------

class _HubCard extends StatefulWidget {
  const _HubCard({required this.item, required this.onTap});

  final _HubItem item;
  final VoidCallback onTap;

  @override
  State<_HubCard> createState() => _HubCardState();
}

class _HubCardState extends State<_HubCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 130,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: item.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: item.colors.last.withValues(alpha: 0.55),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              // Emoji bubble
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Text(item.emoji, style: const TextStyle(fontSize: 40)),
              ),
              const SizedBox(width: 16),

              // Title + subtitle
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: item.colors.last,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PLACEHOLDER — replace with the real My Stats / Friends / Leaderboard pages
// ---------------------------------------------------------------------------

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.emoji,
    required this.colors,
  });

  final String title;
  final String emoji;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming soon 👀',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}