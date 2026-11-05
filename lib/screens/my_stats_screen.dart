import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/friends_repository.dart';
import '../data/mock_friends_repository.dart';
import '../data/mock_stats_repository.dart';
import '../data/stats_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/stat_colors.dart';
import '../utils/format.dart';
import '../widgets/chunky.dart';

// ---------------------------------------------------------------------------
// MY STATS — today's progress toward goals, and the week at a glance
// ---------------------------------------------------------------------------

enum MyStatsView { today, week }

class MyStatsScreen extends StatefulWidget {
  const MyStatsScreen({
    super.key,
    this.friends,
    this.stats,
    this.clock,
    this.goals = const DailyGoals(),
  });

  /// Defaults to mock repositories until the backend exists.
  final FriendsRepository? friends;
  final StatsRepository? stats;
  final DateTime Function()? clock;
  final DailyGoals goals;

  @override
  State<MyStatsScreen> createState() => _MyStatsScreenState();
}

class _MyStatsData {
  const _MyStatsData({
    required this.today,
    required this.week,
    required this.streak,
    required this.weekXp,
  });

  /// Null when nothing has synced today.
  final DailyStats? today;

  /// This week's tracked days, Monday first.
  final List<DailyStats> week;
  final int streak;
  final int weekXp;
}

class _MyStatsScreenState extends State<MyStatsScreen> {
  late final DateTime Function() _clock = widget.clock ?? DateTime.now;
  late final FriendsRepository _friends =
      widget.friends ?? MockFriendsRepository(clock: _clock);
  late final StatsRepository _stats =
      widget.stats ?? MockStatsRepository(friends: _friends, clock: _clock);

  var _view = MyStatsView.today;
  late Future<_MyStatsData> _data = _load();

  Future<_MyStatsData> _load() async {
    final now = _clock();
    final today = dateOnly(now);
    final me = await _friends.currentUser();
    // Far enough back for any realistic streak in the mock data.
    final recent = await _stats.dailyStats(
      me.id,
      from: DateTime(today.year, today.month, today.day - 60),
      to: today,
    );
    final week = WeeklySummary.fromDays(
      userId: me.id,
      weekStart: today,
      stats: recent,
    );
    return _MyStatsData(
      today: recent.where((d) => d.date == today).firstOrNull,
      week: week.days,
      streak: currentStreak(recent, today: today, goals: widget.goals),
      weekXp: weeklyXp(week),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Stats')),
      body: SafeArea(
        top: false,
        child: FutureBuilder<_MyStatsData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Message(
                text: "Couldn't load your stats. Try again in a sec.",
                onRetry: () => setState(() => _data = _load()),
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                _HeaderChips(streak: data.streak, weekXp: data.weekXp),
                const SizedBox(height: 16),
                _ViewToggle(
                  selected: _view,
                  onSelected: (v) => setState(() => _view = v),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (_view) {
                    MyStatsView.today => _TodayView(
                      key: const ValueKey('today'),
                      today: data.today,
                      goals: widget.goals,
                    ),
                    MyStatsView.week => _WeekView(
                      key: const ValueKey('week'),
                      week: data.week,
                      weekStart: startOfWeek(_clock()),
                      today: dateOnly(_clock()),
                      goals: widget.goals,
                    ),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HEADER — streak and XP
// ---------------------------------------------------------------------------

class _HeaderChips extends StatelessWidget {
  const _HeaderChips({required this.streak, required this.weekXp});

  final int streak;
  final int weekXp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HeaderChip(
            key: const ValueKey('streak'),
            emoji: '🔥',
            color: AppColors.orange,
            edge: AppColors.orangeDark,
            value: streak,
            format: (n) => '$n',
            caption: 'day streak',
            semanticLabel: '$streak day streak',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HeaderChip(
            key: const ValueKey('xp'),
            emoji: '⚡',
            color: AppColors.gold,
            edge: AppColors.goldDark,
            value: weekXp,
            format: formatThousands,
            caption: 'XP this week',
            semanticLabel: '${formatThousands(weekXp)} XP this week',
          ),
        ),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    super.key,
    required this.emoji,
    required this.color,
    required this.edge,
    required this.value,
    required this.format,
    required this.caption,
    required this.semanticLabel,
  });

  final String emoji;
  final Color color;
  final Color edge;
  final int value;
  final String Function(int) format;
  final String caption;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: ChunkySurface(
          color: color,
          edgeColor: edge,
          radius: AppRadius.card,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ticks up from 0 when the screen opens.
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: value.toDouble()),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Text(
                        format(v.round()),
                        style: text.headlineMedium?.copyWith(
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                    Text(
                      caption,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(color: Colors.white),
                    ),
                  ],
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
// TODAY / THIS WEEK toggle
// ---------------------------------------------------------------------------

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.selected, required this.onSelected});

  final MyStatsView selected;
  final ValueChanged<MyStatsView> onSelected;

  static const _labels = {
    MyStatsView.today: 'Today',
    MyStatsView.week: 'This week',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final view in MyStatsView.values) ...[
          if (view != MyStatsView.values.first) const SizedBox(width: 10),
          Expanded(
            child: ChunkySurface(
              key: ValueKey('view-${view.name}'),
              color: view == selected ? AppColors.primary : AppColors.surface,
              edgeColor: view == selected
                  ? AppColors.primaryDark
                  : AppColors.border,
              borderColor: view == selected ? null : AppColors.border,
              radius: AppRadius.chip,
              depth: AppDepth.chip,
              selected: view == selected,
              semanticLabel: _labels[view],
              onTap: () => onSelected(view),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    _labels[view]!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: view == selected
                          ? Colors.white
                          : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TODAY — one card per stat with a progress ring
// ---------------------------------------------------------------------------

class _TodayView extends StatelessWidget {
  const _TodayView({super.key, required this.today, required this.goals});

  final DailyStats? today;
  final DailyGoals goals;

  @override
  Widget build(BuildContext context) {
    final today = this.today;
    if (today == null) {
      return const _Message(
        text: 'Nothing synced yet today. Go for a walk and check back! 👟',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          todayHeadline(today, goals),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final metric in StatMetric.values) ...[
          _TodayCard(
            metric: metric,
            value: metric.valueOf(today),
            goals: goals,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.metric,
    required this.value,
    required this.goals,
  });

  final StatMetric metric;
  final int value;
  final DailyGoals goals;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hit = goals.isHit(metric, value);
    final status = goalStatus(metric, value, goals);
    final target = goals.target(metric);
    final ofGoal = metric.higherIsBetter
        ? '${formatStat(metric, value)} / ${formatStat(metric, target)}'
        : '${formatStat(metric, value)} of ${formatStat(metric, target)}';

    return Semantics(
      container: true,
      label: '${metric.label}: $ofGoal. $status',
      child: ExcludeSemantics(
        child: ChunkyCard(
          key: ValueKey('today-${metric.name}'),
          // Celebrate a hit goal with the stat's own color.
          borderColor: hit && metric.higherIsBetter
              ? metric.color
              : AppColors.border,
          edgeColor: hit && metric.higherIsBetter
              ? metric.edgeColor
              : AppColors.border,
          child: Row(
            children: [
              _GoalRing(
                metric: metric,
                progress: goals.progress(metric, value),
                celebrate: hit && metric.higherIsBetter,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label,
                      style: text.labelMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(ofGoal, style: text.titleLarge),
                    const SizedBox(height: 2),
                    Text(status, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A ring that fills toward the goal. When [celebrate] is set, a check pops
/// in with a bounce once the fill finishes.
class _GoalRing extends StatelessWidget {
  const _GoalRing({
    required this.metric,
    required this.progress,
    required this.celebrate,
  });

  final StatMetric metric;
  final double progress;
  final bool celebrate;

  static const _size = 60.0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 1100),
      builder: (context, t, _) {
        // First 60%: the ring fills. Last 40%: the check bounces in.
        final fill = Curves.easeOutCubic.transform((t / 0.6).clamp(0.0, 1.0));
        final pop = Curves.elasticOut.transform(
          ((t - 0.6) / 0.4).clamp(0.0, 1.0),
        );
        return SizedBox.square(
          dimension: _size,
          child: CustomPaint(
            painter: _RingPainter(
              color: metric.color,
              progress: progress * fill,
            ),
            child: Center(
              child: celebrate
                  ? Transform.scale(
                      scale: pop,
                      child: Icon(
                        Icons.check_rounded,
                        key: ValueKey('goal-hit-${metric.name}'),
                        color: metric.color,
                        size: 30,
                      ),
                    )
                  : Text(metric.emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  static const _stroke = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      paint..color = AppColors.border,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ---------------------------------------------------------------------------
// THIS WEEK — a small bar chart per stat, Monday to Sunday
// ---------------------------------------------------------------------------

class _WeekView extends StatelessWidget {
  const _WeekView({
    super.key,
    required this.week,
    required this.weekStart,
    required this.today,
    required this.goals,
  });

  final List<DailyStats> week;
  final DateTime weekStart;
  final DateTime today;
  final DailyGoals goals;

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in week) d.date: d};
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final metric in StatMetric.values) ...[
          _WeekCard(
            metric: metric,
            days: days,
            values: [
              for (final d in days)
                if (byDate[d] case final s?) metric.valueOf(s) else null,
            ],
            today: today,
            goals: goals,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.metric,
    required this.days,
    required this.values,
    required this.today,
    required this.goals,
  });

  final StatMetric metric;
  final List<DateTime> days;

  /// One per day in [days]; null for days with no data.
  final List<int?> values;
  final DateTime today;
  final DailyGoals goals;

  static const _chartHeight = 84.0;
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tracked = values.whereType<int>().toList();
    final summary = weekSummaryLine(metric, tracked, goals);
    final target = goals.target(metric);
    final top = math.max(target, tracked.fold(0, math.max)).toDouble();

    return Semantics(
      container: true,
      label: '${metric.label} this week. $summary',
      child: ExcludeSemantics(
        child: ChunkyCard(
          key: ValueKey('week-${metric.name}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(metric.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(metric.label, style: text.titleMedium)),
                ],
              ),
              const SizedBox(height: 2),
              Text(summary, style: text.bodySmall),
              const SizedBox(height: 12),
              SizedBox(
                height: _chartHeight,
                child: Stack(
                  children: [
                    // Goal line.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _chartHeight * target / top,
                      child: Container(height: 2, color: AppColors.border),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < days.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: _Bar(
                                height: _chartHeight * (values[i] ?? 0) / top,
                                color:
                                    values[i] != null &&
                                        goals.isHit(metric, values[i]!)
                                    ? metric.color
                                    : metric.color.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Text(
                        _dayLetters[i],
                        textAlign: TextAlign.center,
                        style: text.labelSmall?.copyWith(
                          color: days[i] == today
                              ? AppColors.ink
                              : AppColors.muted,
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

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: height),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, h, _) => Container(
        height: math.max(h, 0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MESSAGE — empty / error states
// ---------------------------------------------------------------------------

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.inkSoft),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ChunkyButton(label: 'Try again', onPressed: onRetry, expand: false),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// COPY — friendly, never shaming
// ---------------------------------------------------------------------------

/// How one value of [metric] reads, e.g. "6,240 steps" or "7h 12m".
String formatStat(StatMetric metric, int value) => switch (metric) {
  StatMetric.steps => '${formatThousands(value)} steps',
  StatMetric.sleep || StatMetric.screenTime => formatMinutes(value),
  StatMetric.workout => '$value min',
  StatMetric.calories => '${formatThousands(value)} kcal',
};

/// One encouraging line under a stat on the Today view.
String goalStatus(StatMetric metric, int value, DailyGoals goals) {
  final target = goals.target(metric);
  final gap = (target - value).abs();
  if (metric == StatMetric.screenTime) {
    if (value == 0) return 'Not tracked yet today';
    return value <= target
        ? '${formatMinutes(gap)} left under your limit 📵'
        : 'Past your limit. Tomorrow is a fresh start 🌱';
  }
  if (value >= target) return 'Goal hit! 🎉';
  return switch (metric) {
    StatMetric.steps => '${formatThousands(gap)} steps to go 👟',
    StatMetric.sleep => 'A little short. Rest up tonight 😴',
    StatMetric.workout => '$gap min to go 💪',
    StatMetric.calories => '${formatThousands(gap)} kcal to go 🔥',
    StatMetric.screenTime => '', // handled above
  };
}

/// The headline above the Today cards.
String todayHeadline(DailyStats today, DailyGoals goals) {
  final goalMetrics = StatMetric.values.where((m) => m.higherIsBetter);
  final hit = goalMetrics.where((m) => goals.isHit(m, m.valueOf(today))).length;
  final total = goalMetrics.length;
  if (hit == total) return 'Every goal hit today. Legend! 🏆';
  if (hit == 0) return "Today's still wide open. Let's go! 💪";
  return '$hit of $total goals hit today 🎉';
}

/// Total or average for the week plus how many days hit the goal.
String weekSummaryLine(StatMetric metric, List<int> tracked, DailyGoals goals) {
  if (tracked.isEmpty) return 'No data yet this week';
  final total = tracked.fold(0, (a, b) => a + b);
  final headline = metric.rankByAverage
      ? '${formatStat(metric, (total / tracked.length).round())} a day'
      : '${formatStat(metric, total)} total';
  final hits = tracked.where((v) => goals.isHit(metric, v)).length;
  final verb = metric.higherIsBetter ? 'goal hit' : 'under your limit';
  return '$headline · $verb $hits/${tracked.length} days';
}
