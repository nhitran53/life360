import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/mock_circle.dart';
import '../theme/circle_colors.dart';
import '../widgets/circle_widgets.dart';
import 'member_detail_screen.dart';
import 'nudge_screen.dart';
import 'privacy_screen.dart';

// ---------------------------------------------------------------------------
// CIRCLE — tab shell (Circle / Ranks / Nudges / Privacy) + the Circle home:
// live pulse map of your circle and today's totals
// ---------------------------------------------------------------------------

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key, this.initialTab = CircleTab.circle});

  final CircleTab initialTab;

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  late CircleTab _tab = widget.initialTab;

  CircleMember _nudgeRecipient = circleNudgeMembers.first;

  /// Changes whenever a nudge is started from elsewhere, so the Nudges tab
  /// starts fresh for the new recipient.
  Key _nudgeKey = UniqueKey();

  void _selectTab(CircleTab tab) {
    if (tab == CircleTab.ranks) {
      showCircleSnack(context, 'Ranks is coming soon 👀');
      return;
    }
    setState(() => _tab = tab);
  }

  void _nudge(CircleMember member) {
    setState(() {
      _nudgeRecipient = member;
      _nudgeKey = UniqueKey();
      _tab = CircleTab.nudges;
    });
  }

  void _openMember(CircleMember member) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberDetailScreen(
          member: member,
          onSelectTab: _selectTab,
          onSendNote: _nudge,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CircleColors.background,
      bottomNavigationBar: CircleTabBar(active: _tab, onSelect: _selectTab),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          // Ranks never becomes active, so it has no page yet.
          index: switch (_tab) {
            CircleTab.circle || CircleTab.ranks => 0,
            CircleTab.nudges => 1,
            CircleTab.privacy => 2,
          },
          children: [
            _CircleHome(onOpenMember: _openMember, onNudge: _nudge),
            NudgeScreen(key: _nudgeKey, initialRecipient: _nudgeRecipient),
            const PrivacyScreen(),
          ],
        ),
      ),
    );
  }
}

class _CircleHome extends StatelessWidget {
  const _CircleHome({required this.onOpenMember, required this.onNudge});

  final ValueChanged<CircleMember> onOpenMember;
  final ValueChanged<CircleMember> onNudge;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          const SizedBox(height: 14),
          const _PulseMap(),
          const SizedBox(height: 14),
          const _TogetherToday(steps: circleStepsToday, goal: circleStepsGoal),
          for (final member in circleListMembers) ...[
            SizedBox(height: member == circleListMembers.first ? 14 : 8),
            _MemberRow(
              member: member,
              onTap: () => onOpenMember(member),
              onNudge: member.idle ? () => onNudge(member) : null,
            ),
          ],
        ],
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
              SvgPicture.asset(
                '$circleAssets/icon_users.svg',
                width: 16,
                height: 16,
              ),
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
              SvgPicture.asset(
                '$circleAssets/icon_chevron_down.svg',
                width: 14,
                height: 14,
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            children: [
              SvgPicture.asset(
                '$circleAssets/notifications.svg',
                width: 44,
                height: 44,
              ),
              Positioned(
                left: 25,
                top: 9,
                child: SvgPicture.asset(
                  '$circleAssets/notification_dot.svg',
                  width: 10,
                  height: 10,
                ),
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

  static Widget _svgAt(
    String name, {
    required double left,
    required double top,
    required double size,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: SvgPicture.asset(
        '$circleAssets/$name.svg',
        width: size,
        height: size,
      ),
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
        MemberAvatar(
          initial: initial,
          color: color,
          size: size,
          fontSize: size > 44 ? 17 : 14,
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
          '$circleAssets/${alert ? 'icon_heart_white' : 'icon_heart'}.svg',
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
          SvgPicture.asset('$circleAssets/live_dot.svg', width: 7, height: 7),
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

    return CircleCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Together today',
                  style: label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('Goal ${formatNumber(goal)}', style: label),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatNumber(steps),
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
  const _MemberRow({required this.member, required this.onTap, this.onNudge});

  final CircleMember member;
  final VoidCallback onTap;

  /// When set, shows a Nudge button instead of heart rate + steps.
  final VoidCallback? onNudge;

  @override
  Widget build(BuildContext context) {
    final onNudge = this.onNudge;

    return Material(
      color: CircleColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: CircleColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              MemberAvatar(initial: member.initial, color: member.color),
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
                CirclePillButton(
                  label: 'Nudge',
                  icon: 'icon_send',
                  filled: true,
                  onPressed: onNudge,
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${member.bpm} bpm',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: CircleColors.heart,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatNumber(member.steps)} steps',
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
        ),
      ),
    );
  }
}
