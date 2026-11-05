import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/circle_colors.dart';
import 'leaderboard_screen.dart';

// ---------------------------------------------------------------------------
// CIRCLE (HOME) — live pulse map of your circle + today's totals
// ---------------------------------------------------------------------------

const _assets = 'assets/circle';

/// Placeholder data matching the Figma mock until the repositories
/// expose heart rate and activity.
class _Member {
  const _Member({
    required this.name,
    required this.initial,
    required this.color,
    required this.status,
    this.bpm,
    this.steps,
  });

  final String name;
  final String initial;
  final Color color;
  final String status;
  final int? bpm;
  final int? steps;
}

const _mom = _Member(
  name: 'Mom',
  initial: 'M',
  color: CircleColors.avatarMom,
  status: 'Walking · now',
  bpm: 78,
  steps: 8240,
);
const _dad = _Member(
  name: 'Dad',
  initial: 'D',
  color: CircleColors.avatarDad,
  status: '3,105 steps · idle 3h',
);
const _bao = _Member(
  name: 'Bao',
  initial: 'B',
  color: CircleColors.avatarBao,
  status: 'Running · 24 min',
  bpm: 132,
  steps: 11980,
);

const _stepsToday = 38412;
const _stepsGoal = 50000;

class CircleScreen extends StatelessWidget {
  const CircleScreen({super.key});

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is coming soon 👀')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CircleColors.background,
      bottomNavigationBar: _TabBar(
        onTabTap: (label) => label == 'Ranks'
            ? Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const LeaderboardScreen()))
            : _comingSoon(context, label),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 14),
              const _PulseMap(),
              const SizedBox(height: 14),
              const _TogetherToday(steps: _stepsToday, goal: _stepsGoal),
              const SizedBox(height: 14),
              const _MemberRow(member: _mom),
              const SizedBox(height: 8),
              _MemberRow(
                member: _dad,
                onNudge: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                        const SnackBar(content: Text('Nudge sent to Dad 👋')));
                },
              ),
              const SizedBox(height: 8),
              const _MemberRow(member: _bao),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HEADER — circle switcher + notifications
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: CircleColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: CircleColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset('$_assets/icon_users.svg', width: 16, height: 16),
              const SizedBox(width: 8),
              const Text(
                'Tran family',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CircleColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset('$_assets/icon_chevron_down.svg',
                  width: 14, height: 14),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            children: [
              SvgPicture.asset('$_assets/notifications.svg',
                  width: 44, height: 44),
              Positioned(
                left: 25,
                top: 9,
                child: SvgPicture.asset('$_assets/notification_dot.svg',
                    width: 10, height: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PULSE MAP — rings with members placed around "You"
// ---------------------------------------------------------------------------

class _PulseMap extends StatelessWidget {
  const _PulseMap();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 248,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CircleColors.mapBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      // Positions come straight from the 342×248 design frame.
      child: SizedBox(
        width: 342,
        height: 248,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _svgAt('ring_outer', left: 63, top: 16, size: 216),
            _svgAt('ring_middle', left: 99, top: 52, size: 144),
            _svgAt('ring_inner', left: 135, top: 88, size: 72),
            // Soft red glow behind Bao (high heart rate).
            _svgAt('glow_outer', left: 50, top: 154, size: 68),
            _svgAt('glow_inner', left: 58, top: 162, size: 52),
            const Positioned(
              left: 145,
              top: 92,
              child: _MapMember(
                initial: 'You',
                color: CircleColors.avatarYou,
                size: 52,
                badge: _HeartBadge(bpm: 71),
              ),
            ),
            const Positioned(
              left: 48,
              top: 24,
              child: _MapMember(
                initial: 'M',
                color: CircleColors.avatarMom,
                badge: _HeartBadge(bpm: 78),
              ),
            ),
            const Positioned(
              left: 248,
              top: 40,
              child: _MapMember(
                initial: 'D',
                color: CircleColors.avatarDad,
                ringColor: CircleColors.idle,
                badge: _TextBadge(text: 'idle 3h'),
              ),
            ),
            const Positioned(
              left: 58,
              top: 160,
              child: _MapMember(
                initial: 'B',
                color: CircleColors.avatarBao,
                ringColor: CircleColors.alert,
                badge: _HeartBadge(bpm: 132, alert: true),
              ),
            ),
            const Positioned(
              left: 262,
              top: 128,
              child: _MapMember(
                initial: 'L',
                color: CircleColors.avatarLinh,
                badge: _HeartBadge(bpm: 70),
              ),
            ),
            const Positioned(left: 178, top: 213, child: _LiveChip()),
          ],
        ),
      ),
    );
  }

  static Widget _svgAt(String name,
      {required double left, required double top, required double size}) {
    return Positioned(
      left: left,
      top: top,
      child: SvgPicture.asset('$_assets/$name.svg', width: size, height: size),
    );
  }
}

class _MapMember extends StatelessWidget {
  const _MapMember({
    required this.initial,
    required this.color,
    required this.badge,
    this.size = 44,
    this.ringColor = CircleColors.mapBackground,
  });

  final String initial;
  final Color color;
  final Widget badge;
  final double size;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Avatar(
          initial: initial,
          color: color,
          size: size,
          ringColor: ringColor,
        ),
        const SizedBox(height: 4),
        badge,
      ],
    );
  }
}

class _HeartBadge extends StatelessWidget {
  const _HeartBadge({required this.bpm, this.alert = false});

  final int bpm;

  /// Red pill for a high heart rate.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      color: alert ? CircleColors.alert : CircleColors.surface,
      children: [
        SvgPicture.asset(
          '$_assets/${alert ? 'icon_heart_white' : 'icon_heart'}.svg',
          width: 10,
          height: 10,
        ),
        const SizedBox(width: 3),
        Text(
          '$bpm',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: alert ? Colors.white : CircleColors.heart,
          ),
        ),
      ],
    );
  }
}

class _TextBadge extends StatelessWidget {
  const _TextBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      color: CircleColors.surface,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: CircleColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.children});

  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CircleColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('$_assets/live_dot.svg', width: 7, height: 7),
          const SizedBox(width: 6),
          const Text(
            'Live · synced 1 min ago',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: CircleColors.liveText,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AVATAR — colored circle with an initial
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initial,
    required this.color,
    this.size = 44,
    this.ringColor,
  });

  final String initial;
  final Color color;
  final double size;

  /// Optional 3px ring (used on the pulse map).
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final isYou = color == CircleColors.avatarYou;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: ringColor == null
            ? null
            : Border.all(color: ringColor!, width: 3),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: isYou ? 17 : 14,
          fontWeight: FontWeight.w800,
          color: isYou ? Colors.white : CircleColors.ink,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TOGETHER TODAY — combined steps vs. goal
// ---------------------------------------------------------------------------

class _TogetherToday extends StatelessWidget {
  const _TogetherToday({required this.steps, required this.goal});

  final int steps;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final progress = (steps / goal).clamp(0.0, 1.0);
    const label = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: CircleColors.secondary,
    );

    return _Card(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text('Together today',
                    style: label, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text('Goal ${_formatNumber(goal)}', style: label),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatNumber(steps),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: CircleColors.ink,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'steps · ${(progress * 100).round()}%',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CircleColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: CircleColors.progressTrack,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: CircleColors.progressFill,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MEMBER ROW — avatar, status, and heart rate or a Nudge button
// ---------------------------------------------------------------------------

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, this.onNudge});

  final _Member member;

  /// When set, shows a Nudge button instead of heart rate + steps.
  final VoidCallback? onNudge;

  @override
  Widget build(BuildContext context) {
    final bpm = member.bpm;
    final steps = member.steps;

    return _Card(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _Avatar(initial: member.initial, color: member.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CircleColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.status,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CircleColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (onNudge != null)
            _NudgeButton(onPressed: onNudge!)
          else if (bpm != null && steps != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$bpm bpm',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: CircleColors.heart,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatNumber(steps)} steps',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CircleColors.secondary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CircleColors.ink,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset('$_assets/icon_send.svg', width: 16, height: 16),
              const SizedBox(width: 8),
              const Text(
                'Nudge',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.radius,
    required this.padding,
    required this.child,
  });

  final double radius;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: CircleColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: CircleColors.border),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// TAB BAR — Circle / Ranks / Nudges / Privacy
// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  const _TabBar({required this.onTabTap});

  /// Called with the tab's label for tabs that aren't built yet.
  final ValueChanged<String> onTabTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      decoration: const BoxDecoration(
        color: CircleColors.surface,
        border: Border(top: BorderSide(color: CircleColors.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Tab(icon: 'tab_circle', label: 'Circle', active: true),
            _Tab(
                icon: 'tab_ranks',
                label: 'Ranks',
                onTap: () => onTabTap('Ranks')),
            _Tab(
                icon: 'tab_nudges',
                label: 'Nudges',
                onTap: () => onTabTap('Nudges')),
            _Tab(
                icon: 'tab_privacy',
                label: 'Privacy',
                onTap: () => onTabTap('Privacy')),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final String icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('$_assets/$icon.svg', width: 22, height: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                color: active ? CircleColors.ink : CircleColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 38412 → "38,412".
String _formatNumber(int n) {
  final digits = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}
