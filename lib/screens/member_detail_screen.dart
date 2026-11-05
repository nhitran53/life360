import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/mock_circle.dart';
import '../theme/circle_colors.dart';
import '../widgets/circle_widgets.dart';

// ---------------------------------------------------------------------------
// MEMBER DETAIL — one person's live heart rate, today's stats and their week
// ---------------------------------------------------------------------------

class MemberDetailScreen extends StatelessWidget {
  const MemberDetailScreen({
    super.key,
    required this.member,
    this.onSelectTab,
    this.onSendNote,
  });

  final CircleMember member;

  /// Called after this page closes when a tab other than Circle is tapped.
  final ValueChanged<CircleTab>? onSelectTab;

  /// Called after this page closes to start a nudge to [member].
  final ValueChanged<CircleMember>? onSendNote;

  @override
  Widget build(BuildContext context) {
    void closeThen(VoidCallback? then) {
      Navigator.of(context).maybePop();
      then?.call();
    }

    return Scaffold(
      backgroundColor: CircleColors.background,
      bottomNavigationBar: CircleTabBar(
        active: CircleTab.circle,
        onSelect: (tab) => tab == CircleTab.circle
            ? closeThen(null)
            : closeThen(() => onSelectTab?.call(tab)),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                onBack: () => closeThen(null),
                onMore: () =>
                    showCircleSnack(context, 'More options are coming soon 👀'),
              ),
              const SizedBox(height: 12),
              _Profile(member: member),
              const SizedBox(height: 12),
              _HeartRateCard(member: member),
              const SizedBox(height: 12),
              _StatsGrid(member: member),
              const SizedBox(height: 12),
              _WeekSteps(steps: member.weekSteps),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CirclePillButton(
                      label: 'Send a note',
                      icon: 'icon_send',
                      filled: true,
                      height: 50,
                      fontSize: 15,
                      horizontalPadding: 16,
                      onPressed: () =>
                          closeThen(() => onSendNote?.call(member)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CirclePillButton(
                      label: 'Cheer ${member.objectPronoun} on',
                      height: 50,
                      fontSize: 15,
                      horizontalPadding: 16,
                      onPressed: () => showCircleSnack(
                        context,
                        'You cheered ${member.name} on 🎉',
                      ),
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

// ---------------------------------------------------------------------------
// TOP BAR + PROFILE
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onMore});

  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundIconButton(icon: 'icon_back', tooltip: 'Back', onTap: onBack),
        const Text(
          'Synced 2 min ago',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: CircleColors.secondary,
          ),
        ),
        _RoundIconButton(icon: 'icon_more', tooltip: 'More', onTap: onMore),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: CircleColors.surface,
        shape: const CircleBorder(side: BorderSide(color: CircleColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: CircleSvg(icon, size: 20)),
          ),
        ),
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.member});

  final CircleMember member;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MemberAvatar(
          initial: member.initial,
          color: member.color,
          size: 60,
          fontSize: 19,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: CircleColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Shares ${member.shares}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CircleColors.secondary,
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
// HEART RATE — live bpm with today's curve
// ---------------------------------------------------------------------------

class _HeartRateCard extends StatelessWidget {
  const _HeartRateCard({required this.member});

  final CircleMember member;

  static const _axis = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: CircleColors.muted,
  );

  @override
  Widget build(BuildContext context) {
    return CircleCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleSvg('icon_heart_16', size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Heart rate · live',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CircleColors.secondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: CircleColors.okBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Normal range',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CircleColors.okText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${member.bpm}',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: CircleColors.ink,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'bpm · ${member.activity}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CircleColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _HeartRateChart(),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('6 AM', style: _axis),
              Text('10 AM', style: _axis),
              Text('2 PM', style: _axis),
              Text('Now', style: _axis),
            ],
          ),
        ],
      ),
    );
  }
}

/// The design's chart export. It's 313.2 wide for a 308 wide slot (the end
/// dot pokes out), so it's scaled to the card and nudged left to match.
///
/// Placeholder: every member shows the same curve until real samples exist.
class _HeartRateChart extends StatelessWidget {
  const _HeartRateChart();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 308;
        return SizedBox(
          height: 84,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -1.2 * scale,
                top: 0,
                width: 313.2 * scale,
                height: 84,
                child: SvgPicture.asset(
                  '$circleAssets/hr_chart.svg',
                  fit: BoxFit.fill,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// STATS — steps, active minutes, sleep, resting heart rate
// ---------------------------------------------------------------------------

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.member});

  final CircleMember member;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Steps',
                  value: formatNumber(member.steps),
                  progress: member.steps / circleStepGoal,
                  progressColor: CircleColors.progressFill,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Active minutes',
                  value: '${member.activeMinutes} min',
                  progress: member.activeMinutes / circleActiveGoal,
                  progressColor: CircleColors.active,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Sleep last night',
                  value: member.sleep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Resting heart rate',
                  value: '${member.restingBpm} bpm',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.progress,
    this.progressColor = CircleColors.progressFill,
  });

  final String label;
  final String value;
  final double? progress;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;

    return CircleCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CircleColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: CircleColors.ink,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 4),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: CircleColors.progressTrack,
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// STEPS THIS WEEK — one bar per day, today highlighted
// ---------------------------------------------------------------------------

class _WeekSteps extends StatelessWidget {
  const _WeekSteps({required this.steps});

  /// Monday first; the last entry is today.
  final List<int> steps;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _barHeight = 56.0;

  static const _label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: CircleColors.secondary,
  );

  @override
  Widget build(BuildContext context) {
    final total = steps.fold(0, (sum, s) => sum + s);
    final most = steps.fold(1, math.max);

    return CircleCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Steps this week', style: _label),
              Text(formatNumber(total), style: _label),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _barHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: _barHeight * steps[i] / most,
                      decoration: BoxDecoration(
                        color: i == steps.length - 1
                            ? CircleColors.progressFill
                            : CircleColors.weekBar,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < _days.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _days[i],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: CircleColors.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
