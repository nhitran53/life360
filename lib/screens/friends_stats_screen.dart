import 'package:flutter/material.dart';

import '../data/friend_snapshots.dart';
import '../data/friends_repository.dart';
import '../data/health/fake_health_source.dart';
import '../data/health_stats_repository.dart';
import '../data/mock_friends_repository.dart';
import '../data/mock_stats_repository.dart';
import '../data/sharing_repository.dart';
import '../data/sharing_stats_repository.dart';
import '../data/stats_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/chunky.dart';
import '../widgets/friend_widgets.dart';
import 'add_friends_screen.dart';
import 'friend_detail_screen.dart';

// ---------------------------------------------------------------------------
// FRIENDS' STATS — every friend's day at a glance
// ---------------------------------------------------------------------------

class FriendsStatsScreen extends StatefulWidget {
  const FriendsStatsScreen({
    super.key,
    this.friends,
    this.stats,
    this.sharing,
    this.clock,
  });

  /// Defaults to mock repositories until the backend exists.
  final FriendsRepository? friends;

  /// Should already apply everyone's sharing settings (see
  /// [SharingStatsRepository]); the default does.
  final StatsRepository? stats;

  /// Tells the screen which stats to show as 🔒.
  final SharingRepository? sharing;
  final DateTime Function()? clock;

  @override
  State<FriendsStatsScreen> createState() => _FriendsStatsScreenState();
}

class _FriendsData {
  const _FriendsData({
    required this.myWeek,
    required this.friends,
    required this.requests,
  });

  final WeeklySummary myWeek;
  final List<FriendSnapshot> friends;

  /// Friend requests waiting for you, for the badge on Add friends.
  final int requests;
}

class _FriendsStatsScreenState extends State<FriendsStatsScreen> {
  late final DateTime Function() _clock = widget.clock ?? DateTime.now;
  late final FriendsRepository _friends =
      widget.friends ?? MockFriendsRepository(clock: _clock);
  late final SharingRepository _sharing =
      widget.sharing ?? (_ownSharing = MockSharingRepository());
  MockSharingRepository? _ownSharing;
  late final StatsRepository _stats =
      widget.stats ??
      SharingStatsRepository(
        // Never connected, so everyone's stats come from the mock.
        inner: HealthStatsRepository(
          source: FakeHealthSource(),
          fallback: MockStatsRepository(friends: _friends, clock: _clock),
          friends: _friends,
          clock: _clock,
        ),
        friends: _friends,
        sharing: _sharing,
        clock: _clock,
      );

  late Future<_FriendsData> _data = _load();

  @override
  void dispose() {
    _ownSharing?.dispose();
    super.dispose();
  }

  Future<_FriendsData> _load() async {
    final now = _clock();
    final stats = _stats;
    final sharing = _sharing;
    final me = await _friends.currentUser();
    final friends = await _friends.friends();
    final myWeek = await stats.weeklySummary(me.id, weekOf: now);
    final snapshots = await Future.wait([
      for (final f in friends)
        loadFriendSnapshot(f, stats: stats, sharing: sharing, now: now),
    ]);
    final requests = (await _friends.incomingRequests()).length;
    return _FriendsData(myWeek: myWeek, friends: snapshots, requests: requests);
  }

  Future<void> _openAddFriends() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddFriendsScreen(friends: _friends),
      ),
    );
    // Friends may have been added, accepted or removed.
    if (!mounted) return;
    setState(() {
      _data = _load();
    });
  }

  void _open(FriendSnapshot friend) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendDetailScreen(
          friend: friend.user,
          friends: _friends,
          stats: _stats,
          sharing: _sharing,
          clock: _clock,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Friends' Stats"),
        actions: [
          FutureBuilder<_FriendsData>(
            future: _data,
            builder: (context, snapshot) {
              final requests = snapshot.data?.requests ?? 0;
              return IconButton(
                key: const ValueKey('add-friends'),
                tooltip: requests == 0
                    ? 'Add friends'
                    : 'Add friends, $requests new '
                          '${requests == 1 ? 'request' : 'requests'}',
                onPressed: _openAddFriends,
                icon: Badge(
                  isLabelVisible: requests > 0,
                  label: Text('$requests'),
                  child: const Icon(Icons.person_add_alt_1_rounded),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<_FriendsData>(
          future: _data,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (snapshot.hasError) {
              return _Message(
                text: "Couldn't load your friends' stats. Try again in a sec.",
                onRetry: () => setState(() {
                  _data = _load();
                }),
              );
            }
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (data.friends.isEmpty) {
              return _Message(
                text: 'Add friends to see how they’re doing 👋',
                actionLabel: 'Add friends',
                onAction: _openAddFriends,
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Text("How's everyone doing?", style: text.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Today so far. Tap a friend to compare your week.',
                  style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 16),
                for (final friend in data.friends) ...[
                  _FriendCard(
                    friend: friend,
                    myWeek: data.myWeek,
                    onTap: () => _open(friend),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.myWeek,
    required this.onTap,
  });

  final FriendSnapshot friend;
  final WeeklySummary myWeek;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = friend.user.displayName;
    final steps = StatComparison.of(
      StatMetric.steps,
      mine: myWeek,
      friend: friend,
    );

    return ChunkyCard(
      key: ValueKey('friend-${friend.user.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmojiAvatar(emoji: friend.user.avatarEmoji),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    Text(
                      friend.sharesNothing
                          ? 'Taking a break from sharing 🔒'
                          : stepsNudge(
                              name,
                              steps,
                              formatSteps: formatThousands,
                            ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StreakPill(streak: friend.streak),
            ],
          ),
          if (!friend.sharesNothing) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: MiniStat(
                    metric: StatMetric.steps,
                    value: friend.todayValue(StatMetric.steps),
                    label: 'steps',
                  ),
                ),
                Expanded(
                  child: MiniStat(
                    metric: StatMetric.workout,
                    value: friend.todayValue(StatMetric.workout),
                    label: 'workout',
                  ),
                ),
                Expanded(
                  child: MiniStat(
                    metric: StatMetric.sleep,
                    value: friend.todayValue(StatMetric.sleep),
                    label: 'sleep',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.onRetry,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
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
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              ChunkyButton(
                label: actionLabel!,
                icon: Icons.person_add_alt_1_rounded,
                onPressed: onAction,
                expand: false,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ChunkyButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
