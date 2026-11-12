part of '../my_stats_screen.dart';

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
    required this.denied,
  });

  final List<DailyStats> week;
  final DateTime weekStart;
  final DateTime today;
  final DailyGoals goals;

  /// Metrics the user turned down in their health app.
  final Set<StatMetric> denied;

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
            denied: denied.contains(metric),
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
    required this.denied,
  });

  final StatMetric metric;
  final List<DateTime> days;

  /// One per day in [days]; null for days with no data.
  final List<int?> values;
  final DateTime today;
  final DailyGoals goals;

  /// A denied metric says so instead of charting fake zeros.
  final bool denied;

  static const _chartHeight = 84.0;
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tracked = denied ? <int>[] : values.whereType<int>().toList();
    final summary = denied
        ? 'No access: not allowed in your health app'
        : weekSummaryLine(metric, tracked, goals);
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
                                height: denied
                                    ? 0
                                    : _chartHeight * (values[i] ?? 0) / top,
                                color:
                                    !denied &&
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
