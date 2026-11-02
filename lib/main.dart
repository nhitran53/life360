import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hub_screen.dart';

void main() => runApp(const Friend360App());

class Friend360App extends StatelessWidget {
  const Friend360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Friend 360',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// HOME SCREEN
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  /// Drives the shifting background + floating emojis (loops forever).
  late final AnimationController _bg;

  /// Drives the button's pulsing glow.
  late final AnimationController _pulse;

  /// Plays once when the screen opens (title bounce, fade-ins).
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _bg = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..forward();
  }

  @override
  void dispose() {
    _bg.dispose();
    _pulse.dispose();
    _intro.dispose();
    super.dispose();
  }

  void _enterApp() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const HubScreen(),
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
    // Intro animation pieces, staggered so things "pop" in one after another.
    final titleScale = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );
    final taglineFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
    );
    final buttonPop = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
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
        child: Stack(
          children: [
            // Floating stat emojis drifting up the screen
            Positioned.fill(child: _FloatingEmojis(animation: _bg)),

            // Main content
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // TITLE — bounces in, then wobbles gently
                      ScaleTransition(
                        scale: titleScale,
                        child: AnimatedBuilder(
                          animation: _bg,
                          builder: (context, child) => Transform.rotate(
                            angle: math.sin(_bg.value * 2 * math.pi * 3) * 0.04,
                            child: child,
                          ),
                          child: const _Title(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // TAGLINE
                      FadeTransition(
                        opacity: taglineFade,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.5),
                            end: Offset.zero,
                          ).animate(taglineFade),
                          child: const _Tagline(),
                        ),
                      ),
                      const SizedBox(height: 60),

                      // BUTTON
                      ScaleTransition(
                        scale: buttonPop,
                        child: _PopButton(
                          label: 'ENTER THE ARENA 🚀',
                          pulse: _pulse,
                          onTap: _enterApp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TITLE + TAGLINE
// ---------------------------------------------------------------------------

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Friend',
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.0,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(4, 4),
                blurRadius: 0,
              ),
              Shadow(
                color: const Color(0xFFFF3CAC).withValues(alpha: 0.8),
                blurRadius: 24,
              ),
            ],
          ),
        ),
        Text(
          '360',
          style: TextStyle(
            fontSize: 110,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFFE53B), // sunshine yellow
            height: 1.0,
            letterSpacing: 4,
            shadows: [
              const Shadow(
                color: Color(0xFFFF6B00),
                offset: Offset(6, 6),
                blurRadius: 0,
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(10, 10),
                blurRadius: 0,
              ),
              Shadow(
                color: const Color(0xFFFFE53B).withValues(alpha: 0.9),
                blurRadius: 30,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
      ),
      child: const Text(
        'Sleep. Sweat. Compete. 🏆',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PULSING "POP" BUTTON
// ---------------------------------------------------------------------------

class _PopButton extends StatefulWidget {
  const _PopButton({
    required this.label,
    required this.pulse,
    required this.onTap,
  });

  final String label;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  State<_PopButton> createState() => _PopButtonState();
}

class _PopButtonState extends State<_PopButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.pulse,
      builder: (context, child) {
        final p = Curves.easeInOut.transform(widget.pulse.value);
        final scale = _pressed ? 0.92 : 1.0 + p * 0.06;
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFE53B)
                      .withValues(alpha: 0.35 + 0.4 * p),
                  blurRadius: 20 + 25 * p,
                  spreadRadius: 2 + 6 * p,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE53B), Color(0xFFFF6B00)],
            ),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FLOATING EMOJIS (background decoration)
// ---------------------------------------------------------------------------

class _Floater {
  const _Floater(this.emoji, this.x, this.speed, this.size, this.phase);

  final String emoji;
  final double x; // horizontal position, 0..1 of screen width
  final int speed; // whole number so the loop is seamless
  final double size;
  final double phase; // 0..1 starting offset
}

const _floaters = [
  _Floater('💤', 0.08, 1, 34, 0.00),
  _Floater('🏃', 0.80, 1, 40, 0.30),
  _Floater('💪', 0.25, 2, 30, 0.60),
  _Floater('🔥', 0.65, 1, 36, 0.80),
  _Floater('🏆', 0.45, 1, 44, 0.15),
  _Floater('💧', 0.90, 2, 28, 0.45),
  _Floater('⭐', 0.05, 2, 26, 0.90),
  _Floater('🥇', 0.55, 2, 32, 0.70),
  _Floater('😴', 0.35, 1, 30, 0.55),
  _Floater('👟', 0.72, 2, 30, 0.05),
];

class _FloatingEmojis extends StatelessWidget {
  const _FloatingEmojis({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = animation.value;
              return Stack(
                children: [
                  for (final f in _floaters)
                    Positioned(
                      left: f.x * w +
                          math.sin((t * f.speed + f.phase) * 2 * math.pi * 2) *
                              20,
                      top: (1 - ((t * f.speed + f.phase) % 1.0)) * (h + 120) -
                          60,
                      child: Opacity(
                        opacity: 0.55,
                        child: Text(
                          f.emoji,
                          style: TextStyle(fontSize: f.size),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}