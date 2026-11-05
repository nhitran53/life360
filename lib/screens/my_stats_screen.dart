import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/connectable_stats_repository.dart';
import '../data/health/health_source.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/chunky.dart';

const _shown = [
  StatMetric.steps,
  StatMetric.sleep,
  StatMetric.workout,
  StatMetric.calories,
];

String formatStat(StatMetric m, num v) {
  if (m == StatMetric.sleep) return '${v ~/ 60}h ${(v % 60).round()}m';
  return '${v.round()} ${m.unit}';
}

/// Today's and this week's stats for the current user, with a card to
/// connect and sync Apple Health / Health Connect.
class MyStatsScreen extends StatefulWidget {
  const MyStatsScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<MyStatsScreen> createState() => _MyStatsScreenState();
}

class _MyStatsScreenState extends State<MyStatsScreen> {
  bool _busy = false;
  bool _failed = false;
  late Future<_Data?> _data = _load();

  ConnectableStatsRepository get _stats => widget.services.stats;

  /// Null when a fetch fails. The error is dropped on purpose: its text
  /// could carry health details.
  Future<_Data?> _load() async {
    // Read everything from widget/State before the first await.
    final friends = widget.services.friends;
    final stats = _stats;
    try {
      final me = await friends.currentUser();
      final today = DateTime.now();
      final days = await stats.dailyStats(me.id, from: today, to: today);
      final week = await stats.weeklySummary(me.id);
      return _Data(days.isEmpty ? null : days.first, week);
    } catch (_) {
      return null;
    }
  }

  void _retry() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    var failed = false;
    try {
      await _stats.connect();
    } catch (_) {
      // Never surface or log the error text: it could carry health details.
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = failed;
      _data = _load();
    });
  }

  Future<void> _install() async {
    await _stats.openInstallPage();
  }

  @override
  Widget build(BuildContext context) {
    final denied = _stats.deniedMetrics;
    return Scaffold(
      appBar: AppBar(title: const Text('My Stats')),
      body: FutureBuilder<_Data?>(
        future: _data,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data;
          if (snap.hasError || d == null) {
            return _LoadFailed(onRetry: _retry);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ConnectCard(
                stats: _stats,
                busy: _busy,
                failed: _failed,
                onConnect: _connect,
                onInstall: _install,
              ),
              const SizedBox(height: 16),
              Text('Today', style: Theme.of(context).textTheme.titleLarge),
              for (final m in _shown)
                _StatRow(
                  metric: m,
                  denied: denied.contains(m),
                  value: d.today == null
                      ? '–'
                      : formatStat(m, m.valueOf(d.today!)),
                ),
              const SizedBox(height: 8),
              Text('This week', style: Theme.of(context).textTheme.titleLarge),
              for (final m in _shown)
                _StatRow(
                  metric: m,
                  denied: denied.contains(m),
                  subtitle: m.rankByAverage ? 'daily average' : 'total',
                  value: d.week.daysTracked == 0
                      ? '–'
                      : formatStat(m, m.leaderboardValue(d.week)),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Shown when today's or this week's stats can't be loaded.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('load-failed'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 40),
            const SizedBox(height: 12),
            Text(
              "Couldn't load your stats",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Something went wrong. Try again.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            ChunkyButton(
              key: const ValueKey('retry-button'),
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// A stat line. A denied metric says so instead of showing a fake 0.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.metric,
    required this.denied,
    required this.value,
    this.subtitle,
  });

  final StatMetric metric;
  final bool denied;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('stat-${metric.name}'),
      leading: Text(metric.emoji, style: const TextStyle(fontSize: 28)),
      title: Text(metric.label),
      subtitle: denied
          ? const Text('Not allowed in your health app')
          : subtitle == null
          ? null
          : Text(subtitle!),
      trailing: Text(
        denied ? 'No access' : value,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: denied ? AppColors.inkSoft : null),
      ),
    );
  }
}

/// Connect / sync status for the health source, with the action that fits
/// the current state.
class _ConnectCard extends StatelessWidget {
  const _ConnectCard({
    required this.stats,
    required this.busy,
    required this.failed,
    required this.onConnect,
    required this.onInstall,
  });

  final ConnectableStatsRepository stats;
  final bool busy;
  final bool failed;
  final VoidCallback onConnect;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final source = stats.sourceName;
    final theme = Theme.of(context).textTheme;
    final denied = stats.deniedMetrics;
    final deniedNames = [
      for (final m in _shown)
        if (denied.contains(m)) m.label,
    ];

    final String title;
    final String message;
    final IconData icon;
    final Color iconColor;
    String? installLabel;

    if (failed) {
      title = "Couldn't reach $source";
      message = 'Something went wrong. Try again.';
      icon = Icons.error_outline;
      iconColor = AppColors.red;
    } else if (stats.isConnected) {
      title = '$source connected';
      final at = stats.lastSyncedAt;
      final synced = at == null
          ? 'Synced'
          : 'Synced at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
      message = deniedNames.isEmpty
          ? synced
          : '$synced. ${deniedNames.join(', ')} not allowed: turn '
                '${deniedNames.length == 1 ? 'it' : 'them'} on in $source, '
                'then sync again.';
      icon = deniedNames.isEmpty ? Icons.check_circle : Icons.info_outline;
      iconColor = deniedNames.isEmpty ? AppColors.primary : AppColors.orange;
    } else {
      switch (stats.availability) {
        case HealthAvailability.notInstalled:
          title = '$source is not installed';
          message = 'Install $source, then come back to sync your stats.';
          installLabel = 'Install $source';
        case HealthAvailability.updateRequired:
          title = '$source needs an update';
          message = 'Update $source, then come back to sync your stats.';
          installLabel = 'Update $source';
        case HealthAvailability.unsupported:
          title = '$source is not available';
          message = "This device can't sync health stats. Showing demo data.";
        case HealthAvailability.available:
          title = 'No access to $source';
          message = 'Allow reading your stats in $source, then try again.';
        case null:
          title = 'Showing demo data';
          message = 'Connect $source to sync your real stats.';
      }
      icon = stats.availability == null ? Icons.sync : Icons.warning_amber;
      iconColor = stats.availability == null
          ? AppColors.blue
          : AppColors.orange;
    }

    final unsupported = stats.availability == HealthAvailability.unsupported;
    return ChunkyCard(
      key: const ValueKey('connect-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          if (!unsupported) ...[
            const SizedBox(height: 12),
            if (installLabel != null) ...[
              ChunkyButton(
                key: const ValueKey('install-button'),
                label: installLabel,
                icon: Icons.download,
                onPressed: busy ? null : onInstall,
              ),
              const SizedBox(height: 8),
            ],
            installLabel != null
                ? ChunkyButton.secondary(
                    key: const ValueKey('connect-button'),
                    label: 'Try again',
                    onPressed: busy ? null : onConnect,
                  )
                : ChunkyButton(
                    key: const ValueKey('connect-button'),
                    label: busy
                        ? 'Syncing…'
                        : stats.isConnected
                        ? 'Sync now'
                        : 'Connect $source',
                    icon: stats.isConnected ? Icons.sync : Icons.favorite,
                    onPressed: busy ? null : onConnect,
                  ),
          ],
        ],
      ),
    );
  }
}

class _Data {
  const _Data(this.today, this.week);
  final DailyStats? today;
  final WeeklySummary week;
}
