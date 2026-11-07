import 'package:flutter/material.dart';

import '../data/friend_snapshots.dart';
import '../data/friends_repository.dart';
import '../data/sharing_repository.dart';
import '../data/stats_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/stat_colors.dart';
import '../utils/format.dart';
import '../widgets/chunky.dart';
import '../widgets/friend_widgets.dart';

// ---------------------------------------------------------------------------
// FRIEND — their day, and your week side by side with theirs
// ---------------------------------------------------------------------------

class FriendDetailScreen extends StatefulWidget {
  const FriendDetailScreen({
    super.key,
    required this.friend,
    required this.friends,
    required this.stats,
    required this.sharing,
    this.clock,
  });

  final UserProfile friend;
  final FriendsRepository friends;

  /// Sharing-filtered, as in Friends' Stats.
  final StatsRepository stats;
  final SharingRepository sharing;
  final DateTime Function()? clock;

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _DetailData {
  const _DetailData({required this.friend, required this.myWeek});

  final FriendSnapshot friend;
  final WeeklySummary myWeek;
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  late final DateTime Function() _clock = widget.clock ?? DateTime.now;
  late Future<_DetailData> _data = _load();

  Future<_DetailData> _load() async {
    final now = _clock();
    final stats = widget.stats;
    final me = await widget.friends.currentUser();
    final results = await Future.wait<Object>([
      loadFriendSnapshot(
        widget.friend,
        stats: stats,
        sharing: widget.sharing,
        now: now,
      ),
      stats.weeklySummary(me.id, weekOf: now),
    ]);
    return _DetailData(
      friend: results[0] as FriendSnapshot,
      myWeek: results[1] as WeeklySummary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.friend.displayName)),
      body: SafeArea(
        top: false,
        child: FutureBuilder<_DetailData>(
          future: _data,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: ChunkyButton(
                    label: 'Retry',
                    icon: Icons.refresh,
                    expand: false,
                    onPressed: () => setState(() {
                      _data = _load();
                    }),
                  ),
                ),
              );
            }
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _DetailView(data: data);
          },
        ),
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.data});

  final _DetailData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final friend = data.friend;
    final name = friend.user.displayName;
    final comparisons = [
      for (final m in StatMetric.values)
        StatComparison.of(m, mine: data.myWeek, friend: friend),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        // PROFILE
        Row(
          children: [
            EmojiAvatar(emoji: friend.user.avatarEmoji, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: text.headlineMedium,
                  ),
                  Text(
                    '@${friend.user.username}',
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            StreakPill(streak: friend.streak),
          ],
        ),
        const SizedBox(height: 16),
        if (friend.sharesNothing)
          ChunkyCard(
            color: AppColors.surfaceSunken,
            child: Text(
              '$name is taking a break from sharing 🔒\n'
              "Their stats will be back when they're ready.",
              style: text.bodyMedium,
            ),
          )
        else ...[
          ChunkyCard(
            key: const ValueKey('nudge'),
            color: AppColors.surfaceSunken,
            child: Text(
              stepsNudge(name, comparisons.first, formatSteps: formatThousands),
              style: text.bodyMedium,
            ),
          ),
          const SizedBox(height: 20),

          // TODAY
          Text('$name today', style: text.titleLarge),
          const SizedBox(height: 10),
          ChunkyCard(
            child: Wrap(
              runSpacing: 14,
              children: [
                for (final m in StatMetric.values)
                  FractionallySizedBox(
                    widthFactor: 0.5,
                    child: MiniStat(
                      metric: m,
                      value: friend.todayValue(m),
                      label: m.label.toLowerCase(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // COMPARE
          Text('This week: you vs $name', style: text.titleLarge),
          const SizedBox(height: 10),
          for (final c in comparisons) ...[
            _CompareRow(comparison: c, friendName: name),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

/// One stat, you on the left and the friend on the right. The leader's side
/// lights up in the stat's color with a 👑.
class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.comparison, required this.friendName});

  final StatComparison comparison;
  final String friendName;

  static String _caption(StatMetric m) => switch (m) {
    StatMetric.sleep => 'avg a night',
    StatMetric.screenTime => 'avg a day · less wins',
    _ => 'this week',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = comparison;
    final m = c.metric;
    final leader = c.leader;

    String show(double? v, {bool hidden = false}) =>
        hidden ? lockedValue : (v == null ? '–' : formatStat(m, v));

    final yours = show(c.yours);
    final theirs = show(c.theirs, hidden: c.theirsHidden);

    final verdict = switch (leader) {
      Leader.you => 'you lead',
      Leader.friend => '$friendName leads',
      Leader.tie => 'tied',
      Leader.unknown => c.theirsHidden ? '$friendName keeps it private' : '',
    };

    return Semantics(
      key: ValueKey('compare-${m.name}'),
      container: true,
      excludeSemantics: true,
      label: '${m.label}: you $yours, $friendName $theirs. $verdict',
      child: ChunkyCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(m.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    m.label,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _caption(m),
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Side(
                    who: 'You',
                    value: yours,
                    metric: m,
                    leads: leader == Leader.you,
                    tied: leader == Leader.tie,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Side(
                    who: friendName,
                    value: theirs,
                    metric: m,
                    leads: leader == Leader.friend,
                    tied: leader == Leader.tie,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.who,
    required this.value,
    required this.metric,
    required this.leads,
    required this.tied,
  });

  final String who;
  final String value;
  final StatMetric metric;
  final bool leads;
  final bool tied;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final badge = leads ? ' 👑' : (tied ? ' 🤝' : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: leads
            ? metric.color.withValues(alpha: 0.15)
            : AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: leads ? metric.color : AppColors.border,
          width: leads ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$who$badge',
            overflow: TextOverflow.ellipsis,
            style: text.labelMedium?.copyWith(color: AppColors.inkSoft),
          ),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(
              color: leads ? metric.edgeColor : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
