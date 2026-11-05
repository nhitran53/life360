import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/circle_repository.dart';
import '../data/friends_repository.dart';
import '../data/stats_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/stat_colors.dart';
import '../widgets/chunky.dart';
import '../widgets/circle_type_label.dart';
import 'my_stats_screen.dart';

// ---------------------------------------------------------------------------
// CIRCLE DETAIL — this week's standings, the reward, and last week's winner.
// Only steps and workouts are ranked here: never sleep, screen time or
// calories.
// ---------------------------------------------------------------------------

class CircleDetailScreen extends StatefulWidget {
  const CircleDetailScreen({
    super.key,
    required this.circle,
    required this.circles,
    required this.friends,
    required this.stats,
    this.clock,
  });

  final Circle circle;
  final CircleRepository circles;
  final FriendsRepository friends;
  final StatsRepository stats;
  final DateTime Function()? clock;

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _Standings {
  const _Standings({required this.thisWeek, required this.lastWeek});

  final List<LeaderboardEntry> thisWeek;
  final List<LeaderboardEntry> lastWeek;
}

class _CircleDetailScreenState extends State<CircleDetailScreen> {
  late final DateTime Function() _clock = widget.clock ?? DateTime.now;
  late Circle _circle = widget.circle;
  late final Future<UserProfile> _me = widget.friends.currentUser();
  final _cache = <RewardMetric, Future<_Standings>>{};

  var _metric = RewardMetric.steps;
  String? _leaveError;
  var _leaving = false;

  Future<_Standings> _standings(RewardMetric metric) {
    // Read everything from widget/State before the first await.
    final stats = widget.stats;
    final ids = _circle.memberIds;
    final now = _clock();
    final lastWeekOf = DateTime(now.year, now.month, now.day - 7);
    return _cache.putIfAbsent(metric, () async {
      final results = await Future.wait([
        stats.leaderboard(metric.stat, weekOf: now, userIds: ids),
        stats.leaderboard(metric.stat, weekOf: lastWeekOf, userIds: ids),
      ]);
      return _Standings(thisWeek: results[0], lastWeek: results[1]);
    });
  }

  Future<void> _editReward() async {
    final updated = await showModalBottomSheet<Circle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _RewardSheet(circle: _circle, repository: widget.circles),
    );
    if (updated != null && mounted) setState(() => _circle = updated);
  }

  Future<void> _leave() async {
    setState(() {
      _leaving = true;
      _leaveError = null;
    });
    try {
      await widget.circles.leave(_circle.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on CircleException catch (e) {
      if (!mounted) return;
      setState(() {
        _leaving = false;
        _leaveError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_circle.name)),
      body: SafeArea(
        top: false,
        child: FutureBuilder<UserProfile>(
          future: _me,
          builder: (context, meSnapshot) {
            final me = meSnapshot.data;
            if (me == null) {
              return meSnapshot.hasError
                  ? const Center(child: Text("Couldn't load this circle."))
                  : const Center(child: CircularProgressIndicator());
            }
            final isOwner = _circle.ownerId == me.id;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Text(
                  '${_circle.type.emoji} ${_circle.type.label} · '
                  '${memberCountLabel(_circle.memberIds.length)}',
                  style: text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Invite code: ${_circle.inviteCode}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 16),
                _RewardBanner(
                  rewardText: _circle.rewardText,
                  isOwner: isOwner,
                  onEdit: _editReward,
                ),
                const SizedBox(height: 16),
                _MetricToggle(
                  selected: _metric,
                  onSelected: (m) => setState(() => _metric = m),
                ),
                const SizedBox(height: 16),
                FutureBuilder<_Standings>(
                  // New state per metric, so old standings never show under
                  // the other metric's label.
                  key: ValueKey(_metric),
                  future: _standings(_metric),
                  builder: (context, snapshot) {
                    final standings = snapshot.data;
                    if (standings == null) {
                      return snapshot.hasError
                          ? Text(
                              "Couldn't load the standings. Try again in a sec.",
                              style: text.bodyMedium,
                            )
                          : const Center(child: CircularProgressIndicator());
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('This week', style: text.titleMedium),
                        const SizedBox(height: 8),
                        for (final entry in standings.thisWeek) ...[
                          _StandingRow(
                            entry: entry,
                            metric: _metric,
                            isMe: entry.user.id == me.id,
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 8),
                        _WinnerCard(
                          metric: _metric,
                          lastWeek: standings.lastWeek,
                          rewardText: _circle.rewardText,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (_leaveError != null) ...[
                  Text(
                    _leaveError!,
                    key: const ValueKey('leave-error'),
                    style: text.bodyMedium?.copyWith(color: AppColors.redText),
                  ),
                  const SizedBox(height: 8),
                ],
                ChunkyButton.secondary(
                  key: const ValueKey('leave-button'),
                  label: _leaving ? 'Leaving…' : 'Leave circle',
                  icon: Icons.logout_rounded,
                  onPressed: _leaving ? null : _leave,
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
// REWARD BANNER
// ---------------------------------------------------------------------------

class _RewardBanner extends StatelessWidget {
  const _RewardBanner({
    required this.rewardText,
    required this.isOwner,
    required this.onEdit,
  });

  final String? rewardText;
  final bool isOwner;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reward = rewardText;
    return ChunkyCard(
      key: const ValueKey('reward-banner'),
      color: AppColors.gold.withValues(alpha: 0.15),
      borderColor: AppColors.gold,
      edgeColor: AppColors.goldDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎁 Weekly reward', style: text.labelMedium),
          const SizedBox(height: 4),
          Text(
            reward ?? 'No reward set yet',
            key: const ValueKey('reward-text'),
            style: text.titleLarge,
          ),
          if (isOwner) ...[
            const SizedBox(height: 12),
            ChunkyButton.secondary(
              key: const ValueKey('edit-reward-button'),
              label: reward == null ? 'Set reward' : 'Edit reward',
              icon: Icons.edit_rounded,
              expand: false,
              onPressed: onEdit,
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardSheet extends StatefulWidget {
  const _RewardSheet({required this.circle, required this.repository});

  final Circle circle;
  final CircleRepository repository;

  @override
  State<_RewardSheet> createState() => _RewardSheetState();
}

class _RewardSheetState extends State<_RewardSheet> {
  late final _controller = TextEditingController(
    text: widget.circle.rewardText ?? '',
  );
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Blank text clears the reward.
      final updated = await widget.repository.setReward(
        widget.circle.id,
        _controller.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on CircleException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Weekly reward', style: text.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'What does the winner get? Leave it blank to clear the reward.',
            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('reward-field'),
            controller: _controller,
            maxLength: maxRewardLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: const InputDecoration(
              hintText: 'Winner picks the restaurant',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const ValueKey('reward-error'),
              style: text.bodyMedium?.copyWith(color: AppColors.redText),
            ),
          ],
          const SizedBox(height: 16),
          ChunkyButton(
            key: const ValueKey('reward-save-button'),
            label: _saving ? 'Saving…' : 'Save',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// METRIC TOGGLE — steps or workouts only
// ---------------------------------------------------------------------------

class _MetricToggle extends StatelessWidget {
  const _MetricToggle({required this.selected, required this.onSelected});

  final RewardMetric selected;
  final ValueChanged<RewardMetric> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final metric in RewardMetric.values) ...[
          if (metric != RewardMetric.values.first) const SizedBox(width: 10),
          Expanded(
            child: ChunkySurface(
              key: ValueKey('metric-${metric.name}'),
              color: metric == selected ? metric.stat.color : AppColors.surface,
              edgeColor: metric == selected
                  ? metric.stat.edgeColor
                  : AppColors.border,
              borderColor: metric == selected ? null : AppColors.border,
              radius: AppRadius.chip,
              depth: AppDepth.chip,
              selected: metric == selected,
              semanticLabel: metric.stat.label,
              onTap: () => onSelected(metric),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      '${metric.stat.emoji} ${metric.stat.label}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: metric == selected
                            ? Colors.white
                            : AppColors.inkSoft,
                      ),
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
// STANDINGS + WINNER
// ---------------------------------------------------------------------------

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.entry,
    required this.metric,
    required this.isMe,
  });

  final LeaderboardEntry entry;
  final RewardMetric metric;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final value = entry.value > 0
        ? formatStat(metric.stat, entry.value.round())
        : 'No data yet';
    return Semantics(
      container: true,
      label: '${entry.rank}. ${entry.user.displayName}, $value',
      child: ExcludeSemantics(
        child: ChunkyCard(
          key: ValueKey('standing-${entry.user.id}'),
          color: isMe ? AppColors.primaryTint : AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('${entry.rank}', style: text.titleMedium),
              ),
              Text(
                entry.user.avatarEmoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(entry.user.displayName, style: text.titleMedium),
              ),
              Text(value, style: text.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({
    required this.metric,
    required this.lastWeek,
    required this.rewardText,
  });

  final RewardMetric metric;
  final List<LeaderboardEntry> lastWeek;
  final String? rewardText;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final winnerIds = rewardWinners(metric, lastWeek);
    final names = [
      for (final e in lastWeek)
        if (winnerIds.contains(e.user.id)) e.user.displayName,
    ];
    final reward = rewardText;
    return ChunkyCard(
      key: const ValueKey('winner-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🏆 Last week · ${metric.stat.label}', style: text.labelMedium),
          const SizedBox(height: 4),
          if (names.isEmpty)
            Text(
              'No winner last week. Nobody logged any '
              '${metric.stat.label.toLowerCase()}.',
              key: const ValueKey('winner-empty'),
              style: text.bodyMedium,
            )
          else ...[
            Text(
              '${names.join(' & ')} won',
              key: const ValueKey('winner-names'),
              style: text.titleLarge,
            ),
            if (reward != null) ...[
              const SizedBox(height: 2),
              Text('Reward: $reward', style: text.bodyMedium),
            ],
          ],
        ],
      ),
    );
  }
}
