part of '../my_stats_screen.dart';

// ---------------------------------------------------------------------------
// TODAY — one card per stat with a progress ring
// ---------------------------------------------------------------------------

class _TodayView extends StatelessWidget {
  const _TodayView({
    super.key,
    required this.today,
    required this.goals,
    required this.denied,
    this.onLogScreenTime,
    this.onAllowScreenTime,
  });

  final DailyStats? today;
  final DailyGoals goals;

  /// Metrics the user turned down in their health app.
  final Set<StatMetric> denied;

  /// Null hides the button to log screen time by hand.
  final VoidCallback? onLogScreenTime;

  /// Null hides the button to let the phone track screen time.
  final VoidCallback? onAllowScreenTime;

  @override
  Widget build(BuildContext context) {
    final today = this.today;
    final onLog = onLogScreenTime;
    final onAllow = onAllowScreenTime;
    if (today == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Message(
            text: 'Nothing synced yet today. Go for a walk and check back! 👟',
          ),
          if (onAllow != null) ...[
            _AllowScreenTimeButton(onTap: onAllow),
            const SizedBox(height: 8),
          ],
          if (onLog != null) _LogScreenTimeButton(logged: false, onTap: onLog),
        ],
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
            denied: denied.contains(metric),
          ),
          if (metric == StatMetric.screenTime && onAllow != null) ...[
            const SizedBox(height: 8),
            _AllowScreenTimeButton(onTap: onAllow),
          ],
          if (metric == StatMetric.screenTime && onLog != null) ...[
            const SizedBox(height: 8),
            _LogScreenTimeButton(
              logged: today.screenTimeMinutes > 0,
              onTap: onLog,
            ),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Opens Android's usage access settings so the phone can track screen time.
class _AllowScreenTimeButton extends StatelessWidget {
  const _AllowScreenTimeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChunkyButton(
    key: const ValueKey('screen-time-access'),
    label: 'Track screen time automatically',
    icon: Icons.phone_android_rounded,
    color: StatMetric.screenTime.color,
    edgeColor: StatMetric.screenTime.edgeColor,
    onPressed: onTap,
  );
}

class _LogScreenTimeButton extends StatelessWidget {
  const _LogScreenTimeButton({required this.logged, required this.onTap});

  final bool logged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChunkyButton.secondary(
    key: const ValueKey('log-screen-time'),
    label: logged ? 'Edit screen time' : 'Log screen time',
    icon: Icons.edit_rounded,
    onPressed: onTap,
  );
}

/// Bottom sheet to type in today's screen time in 15-minute steps.
/// Pops the chosen minutes, 0 to clear, or nothing when dismissed.
class _ScreenTimeSheet extends StatefulWidget {
  const _ScreenTimeSheet({required this.initial});

  final int initial;

  @override
  State<_ScreenTimeSheet> createState() => _ScreenTimeSheetState();
}

class _ScreenTimeSheetState extends State<_ScreenTimeSheet> {
  static const _step = 15;

  /// A sensible starting point when nothing is logged yet.
  static const _startAt = 2 * 60;

  late int _minutes = widget.initial > 0 ? widget.initial : _startAt;

  void _add(int delta) => setState(() {
    _minutes = (_minutes + delta).clamp(0, ScreenTimeLog.maxMinutes);
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final metric = StatMetric.screenTime;
    Widget step(String key, String label, int delta) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChunkyButton.secondary(
          key: ValueKey(key),
          label: label,
          onPressed: () => _add(delta),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        key: const ValueKey('screen-time-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${metric.emoji} Screen time today',
            style: text.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Check your phone settings and round to the nearest 15 min. '
            'Only you see this unless you share it.',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              formatMinutes(_minutes),
              key: const ValueKey('screen-time-value'),
              textAlign: TextAlign.center,
              style: text.displaySmall?.copyWith(color: metric.color),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              step('screen-time-minus-hour', '−1h', -60),
              step('screen-time-minus', '−15m', -_step),
              step('screen-time-plus', '+15m', _step),
              step('screen-time-plus-hour', '+1h', 60),
            ],
          ),
          const SizedBox(height: 16),
          ChunkyButton(
            key: const ValueKey('screen-time-save'),
            label: 'Save',
            icon: Icons.check_rounded,
            color: metric.color,
            edgeColor: metric.edgeColor,
            onPressed: () => Navigator.of(context).pop(_minutes),
          ),
          if (widget.initial > 0) ...[
            const SizedBox(height: 8),
            ChunkyButton.secondary(
              key: const ValueKey('screen-time-clear'),
              label: 'Clear for today',
              onPressed: () => Navigator.of(context).pop(0),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.metric,
    required this.value,
    required this.goals,
    required this.denied,
  });

  final StatMetric metric;
  final int value;
  final DailyGoals goals;

  /// A denied metric says so instead of showing a fake 0.
  final bool denied;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hit = !denied && goals.isHit(metric, value);
    final status = denied
        ? 'Not allowed in your health app'
        : goalStatus(metric, value, goals);
    final target = goals.target(metric);
    final ofGoal = denied
        ? 'No access'
        : metric.higherIsBetter
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
                progress: denied ? 0 : goals.progress(metric, value),
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
