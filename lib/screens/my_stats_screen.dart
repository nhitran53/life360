import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/connectable_stats_repository.dart';
import '../data/device_screen_time.dart';
import '../data/friends_repository.dart';
import '../data/health/health_source.dart';
import '../data/mock_friends_repository.dart';
import '../data/mock_stats_repository.dart';
import '../data/screen_time_log.dart';
import '../data/stats_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/stat_colors.dart';
import '../utils/format.dart';
import '../widgets/badge_row.dart';
import '../widgets/chunky.dart';

part 'my_stats/today_view.dart';
part 'my_stats/week_view.dart';
part 'my_stats/connect_card.dart';

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
    this.screenTimeLog,
    this.deviceScreenTime = const NoDeviceScreenTime(),
  });

  /// Defaults to mock repositories until the backend exists. When [stats] is a
  /// [ConnectableStatsRepository], a card to connect and sync the health
  /// source is shown above the stats.
  final FriendsRepository? friends;
  final StatsRepository? stats;
  final DateTime Function()? clock;
  final DailyGoals goals;

  /// Where to save screen time the user logs by hand. When set, Today shows
  /// a button to log it. [stats] should merge these entries back in (see
  /// `ManualScreenTimeRepository`), or the logged value won't show.
  final ScreenTimeLog? screenTimeLog;

  /// Screen time the phone measures. When it's supported but access is off,
  /// Today offers to turn it on. [stats] should read from the same source
  /// (see `ManualScreenTimeRepository`).
  final DeviceScreenTime deviceScreenTime;

  @override
  State<MyStatsScreen> createState() => _MyStatsScreenState();
}

class _MyStatsData {
  const _MyStatsData({
    required this.today,
    required this.week,
    required this.streak,
    required this.weekXp,
    required this.badges,
    required this.screenTimeAccess,
  });

  /// Whether the phone's screen time can be read; null where the phone
  /// can't measure it at all.
  final bool? screenTimeAccess;

  /// Null when nothing has synced today.
  final DailyStats? today;

  /// This week's tracked days, Monday first.
  final List<DailyStats> week;
  final StreakStatus streak;
  final int weekXp;
  final List<RewardBadge> badges;
}

class _MyStatsScreenState extends State<MyStatsScreen>
    with WidgetsBindingObserver {
  late final DateTime Function() _clock = widget.clock ?? DateTime.now;
  late final FriendsRepository _friends =
      widget.friends ?? MockFriendsRepository(clock: _clock);
  late final StatsRepository _stats =
      widget.stats ?? MockStatsRepository(friends: _friends, clock: _clock);

  var _view = MyStatsView.today;
  var _syncing = false;
  var _syncFailed = false;
  late Future<_MyStatsData> _data = _restoreAndLoad();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from Settings may have turned usage access on.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!widget.deviceScreenTime.isSupported) return;
    setState(() {
      _data = _load();
    });
  }

  /// The stats source when it can connect to a health platform.
  ConnectableStatsRepository? get _connectable {
    final stats = _stats;
    return stats is ConnectableStatsRepository ? stats : null;
  }

  /// First load: reconnect a previously connected health source so the card
  /// opens on Sync, not Connect.
  Future<_MyStatsData> _restoreAndLoad() async {
    await _connectable?.restoreConnection();
    return _load();
  }

  Future<_MyStatsData> _load() async {
    // Read everything from widget/State before the first await.
    final goals = widget.goals;
    final friends = _friends;
    final stats = _stats;
    final device = widget.deviceScreenTime;
    final now = _clock();
    final today = dateOnly(now);
    final me = await friends.currentUser();
    // Far enough back for any realistic streak in the mock data.
    final recent = await stats.dailyStats(
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
      streak: streakWithFreezes(recent, today: today, goals: goals),
      weekXp: weeklyXp(week),
      badges: earnedBadges(recent, goals: goals),
      screenTimeAccess: device.isSupported ? await device.hasAccess() : null,
    );
  }

  Future<void> _connect(ConnectableStatsRepository stats) async {
    setState(() => _syncing = true);
    var failed = false;
    try {
      await stats.connect();
    } catch (_) {
      // Never surface or log the error text: it could carry health details.
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _syncFailed = failed;
      _data = _load();
    });
  }

  /// Opens the screen time sheet, then saves and reloads.
  Future<void> _logScreenTime(ScreenTimeLog log, int current) async {
    final day = dateOnly(_clock());
    final minutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScreenTimeSheet(initial: current),
    );
    if (minutes == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await log.setMinutes(day, minutes);
    } catch (_) {
      // Never surface the error text: it could carry health details.
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save that. Try again.")),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _data = _load();
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          minutes == 0 ? 'Screen time cleared' : 'Screen time logged 📱',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectable = _connectable;
    final log = widget.screenTimeLog;
    final denied = connectable?.deniedMetrics ?? const <StatMetric>{};
    return Scaffold(
      appBar: AppBar(title: const Text('My Stats')),
      body: SafeArea(
        top: false,
        child: FutureBuilder<_MyStatsData>(
          future: _data,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null &&
                snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || data == null) {
              return _Message(
                text: "Couldn't load your stats. Try again in a sec.",
                onRetry: () => setState(() {
                  _data = _load();
                }),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                if (connectable != null) ...[
                  _ConnectCard(
                    stats: connectable,
                    busy: _syncing,
                    failed: _syncFailed,
                    onConnect: () => _connect(connectable),
                    onInstall: connectable.openInstallPage,
                  ),
                  const SizedBox(height: 16),
                ],
                _HeaderChips(streak: data.streak.days, weekXp: data.weekXp),
                const SizedBox(height: 10),
                _FreezeLine(streak: data.streak),
                const SizedBox(height: 12),
                BadgeRow(key: const ValueKey('badge-row'), badges: data.badges),
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
                      denied: denied,
                      onAllowScreenTime: data.screenTimeAccess == false
                          ? widget.deviceScreenTime.openAccessSettings
                          : null,
                      onLogScreenTime: log == null
                          ? null
                          : () => _logScreenTime(
                              log,
                              data.today?.screenTimeMinutes ?? 0,
                            ),
                    ),
                    MyStatsView.week => _WeekView(
                      key: const ValueKey('week'),
                      week: data.week,
                      weekStart: startOfWeek(_clock()),
                      today: dateOnly(_clock()),
                      goals: widget.goals,
                      denied: denied,
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

/// Streak freezes banked, and when one last saved the streak.
class _FreezeLine extends StatelessWidget {
  const _FreezeLine({required this.streak});

  final StreakStatus streak;

  @override
  Widget build(BuildContext context) {
    final text = freezeLine(streak, MaterialLocalizations.of(context));
    return Row(
      key: const ValueKey('freeze-line'),
      children: [
        Icon(Icons.ac_unit_rounded, size: 18, color: AppColors.blue),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkSoft),
          ),
        ),
      ],
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
            ChunkyButton(
              key: const ValueKey('retry-button'),
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: onRetry,
              expand: false,
            ),
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

/// The line under the streak chip about streak freezes.
String freezeLine(StreakStatus streak, MaterialLocalizations l10n) {
  final saved = streak.frozenDays.lastOrNull;
  final savedText = saved == null
      ? ''
      : ' A freeze saved your streak on ${l10n.formatShortMonthDay(saved)} 🧊';
  if (streak.freezesLeft > 0) {
    final n = streak.freezesLeft;
    return '$n streak ${n == 1 ? 'freeze' : 'freezes'} ready.$savedText';
  }
  if (saved != null) return savedText.trim();
  return 'Keep a ${StreakFreezeRules.daysPerFreeze}-day streak to earn a '
      'streak freeze 🧊';
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
