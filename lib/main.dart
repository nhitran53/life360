import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data/account_session.dart';
import 'data/mock_auth_repository.dart';
import 'data/mock_profile_repository.dart';
import 'models/stat_metric.dart';
import 'screens/auth_gate.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/sign_in_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/stat_colors.dart';
import 'widgets/chunky.dart';

void main() => runApp(const Friend360App());

class Friend360App extends StatefulWidget {
  const Friend360App({super.key, this.session});

  /// Defaults to in-memory mock accounts until Firebase is connected.
  final AccountSession? session;

  @override
  State<Friend360App> createState() => _Friend360AppState();
}

class _Friend360AppState extends State<Friend360App> {
  late final AccountSession _session = widget.session ??
      (_ownSession = AccountSession(
        auth: MockAuthRepository(),
        profiles: MockProfileRepository(),
      ));
  AccountSession? _ownSession;

  @override
  void dispose() {
    _ownSession?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccountScope(
      session: _session,
      child: MaterialApp(
        title: 'Friend 360',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AuthGate(welcome: HomeScreen()),
        routes: {
          privacyPolicyRoute: (_) => const PrivacyPolicyScreen(),
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HOME SCREEN — logo ring, name, one big button
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// Plays once: the stat ring sweeps in, then "360" pops.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.isAnimating || _intro.isCompleted) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    reduceMotion ? _intro.value = 1 : _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _openSignIn(SignInMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignInScreen(initialMode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Center(child: _StatRing(animation: _intro)),
                    const SizedBox(height: 32),
                    Text(
                      'Friend 360',
                      textAlign: TextAlign.center,
                      style: text.displayLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Share your steps, sleep and screen time.\n'
                      'See who wins the week.',
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(color: AppColors.inkSoft),
                    ),
                    const Spacer(flex: 2),
                    const SizedBox(height: 32),
                    ChunkyButton(
                      label: "Let's go",
                      onPressed: () => _openSignIn(SignInMode.signUp),
                    ),
                    const SizedBox(height: 12),
                    ChunkyButton.secondary(
                      label: 'I already have an account',
                      onPressed: () => _openSignIn(SignInMode.logIn),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You choose which stats friends can see.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The logo: one arc per stat, in each stat's color, closing into a full
/// 360° ring around the number.
class _StatRing extends StatelessWidget {
  const _StatRing({required this.animation});

  final Animation<double> animation;

  static const _size = 196.0;

  @override
  Widget build(BuildContext context) {
    final sweep = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
    );
    final pop = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.45, 1, curve: Curves.elasticOut),
    );

    return Semantics(
      label: 'Friend 360 logo',
      child: SizedBox.square(
        dimension: _size,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) => CustomPaint(
            painter: _RingPainter(progress: sweep.value),
            child: Center(
              child: Transform.scale(
                scale: pop.value,
                child: ExcludeSemantics(
                  child: Text(
                    '360',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 52),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  static const _stroke = 20.0;
  static const _gap = 0.30; // radians between arcs (before round caps)

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = StatMetric.values;
    final rect = (Offset.zero & size).deflate(_stroke / 2 + 2);
    final each = 2 * math.pi / metrics.length;

    for (var i = 0; i < metrics.length; i++) {
      // Arcs draw in one after another.
      final local = (progress * metrics.length - i).clamp(0.0, 1.0);
      if (local == 0) continue;
      final start = -math.pi / 2 + i * each + _gap / 2;
      final sweep = (each - _gap) * local;

      // Darker copy underneath, nudged down: the same "3D" edge as buttons.
      canvas.drawArc(
        rect.shift(const Offset(0, 4)),
        start,
        sweep,
        false,
        _paint(metrics[i].edgeColor),
      );
      canvas.drawArc(rect, start, sweep, false, _paint(metrics[i].color));
    }
  }

  Paint _paint(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = _stroke
    ..strokeCap = StrokeCap.round;

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
