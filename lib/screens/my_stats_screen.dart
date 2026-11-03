import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/models.dart';

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

/// Today's and this week's stats for the current user, with a button to
/// connect Apple Health / Health Connect.
class MyStatsScreen extends StatefulWidget {
  const MyStatsScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<MyStatsScreen> createState() => _MyStatsScreenState();
}

class _MyStatsScreenState extends State<MyStatsScreen> {
  bool _busy = false;
  String? _message;
  late Future<_Data> _data = _load();

  Future<_Data> _load() async {
    final me = await widget.services.friends.currentUser();
    final today = DateTime.now();
    final days = await widget.services.stats
        .dailyStats(me.id, from: today, to: today);
    final week = await widget.services.stats.weeklySummary(me.id);
    return _Data(days.isEmpty ? null : days.first, week);
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final ok = await widget.services.stats.connect();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? null : 'Could not get health access. Check permissions.';
      _data = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.services.stats.isConnected;
    return Scaffold(
      appBar: AppBar(title: const Text('My Stats')),
      body: FutureBuilder<_Data>(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: Icon(connected ? Icons.favorite : Icons.sync),
                  title: Text(connected
                      ? 'Health connected'
                      : 'Showing demo data'),
                  subtitle: Text(_message ??
                      (connected
                          ? 'Synced from your health app'
                          : 'Connect to sync your real stats')),
                  trailing: FilledButton(
                    onPressed: _busy ? null : _connect,
                    child: Text(connected ? 'Refresh' : 'Connect'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Today', style: Theme.of(context).textTheme.titleLarge),
              for (final m in _shown)
                ListTile(
                  leading: Text(m.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text(m.label),
                  trailing: Text(
                    d.today == null ? '–' : formatStat(m, m.valueOf(d.today!)),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              const SizedBox(height: 8),
              Text('This week', style: Theme.of(context).textTheme.titleLarge),
              for (final m in _shown)
                ListTile(
                  leading: Text(m.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text(m.label),
                  subtitle: Text(m.rankByAverage ? 'daily average' : 'total'),
                  trailing: Text(
                    formatStat(m, m.leaderboardValue(d.week)),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Data {
  const _Data(this.today, this.week);
  final DailyStats? today;
  final WeeklySummary week;
}
