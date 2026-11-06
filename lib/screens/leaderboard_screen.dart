import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/family_store.dart';
import '../data/friends_repository.dart';
import '../data/mock_circle.dart';
import '../data/mock_friends_repository.dart';
import '../data/mock_stats_repository.dart';
import '../data/sharing_repository.dart';
import '../data/stats_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/stat_colors.dart';
import '../utils/format.dart';
import '../widgets/chunky.dart';
import 'my_stats_screen.dart';

// ---------------------------------------------------------------------------
// LEADERBOARD — weekly ranking among friends, top 3 on a podium
// ---------------------------------------------------------------------------

/// The boards you can switch between.
enum LeaderboardBoard {
  xp('Overall XP', Icons.bolt_rounded, null),
  steps('Steps', Icons.directions_walk_rounded, StatMetric.steps),
  sleep('Sleep', Icons.bedtime_rounded, StatMetric.sleep),
  workout('Workouts', Icons.fitness_center_rounded, StatMetric.workout),
  screenTime('Least screen time', Icons.phone_iphone_rounded,
      StatMetric.screenTime);

  const LeaderboardBoard(this.label, this.icon, this.metric);

  final String label;
  final IconData icon;

  /// Null for the Overall XP board.
  final StatMetric? metric;

  Color get color => metric?.color ?? AppColors.gold;
  Color get edgeColor => metric?.edgeColor ?? AppColors.goldDark;

  /// One line explaining what the number means.
  String get caption => switch (this) {
    xp => 'XP from steps, workouts, sleep and screen time.',
    steps => 'Total steps this week.',
    sleep => 'Average sleep per night.',
    workout => 'Total workout minutes this week.',
    screenTime => 'Average per day. Less wins.',
  };

  /// How a leaderboard value reads, e.g. "62,140 steps" or "7h 12m".
  String format(double value) => switch (this) {
    xp => '${formatThousands(value.round())} XP',
    steps => '${formatThousands(value.round())} steps',
    workout => '${formatThousands(value.round())} min',
    sleep || screenTime => formatMinutes(value.round()),
  };
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    this.friends,
    this.stats,
    this.clock,
    this.initialFamily,
    this.familyStore,
    this.sharing,
  });

  /// Defaults to mock repositories until the backend exists.
  final FriendsRepository? friends;
  final StatsRepository? stats;
  final DateTime Function()? clock;

  /// Which family to rank at first. Null ranks all your friends.
  final CircleFamily? initialFamily;

  /// Families you can switch to. Defaults to [FamilyStore.instance].
  final FamilyStore? familyStore;

  /// Used to explain why you're missing from a board you keep private.
  /// The filtering itself happens in [stats].
  final SharingRepository? sharing;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _BoardData {
  const _BoardData({
    required this.entries,
    required this.lastWeekRanks,
    required this.meId,
    this.youKeepPrivate = false,
  });

  final List<LeaderboardEntry> entries;

  /// User id → rank on the same board last week.
  final Map<String, int> lastWeekRanks;
  final String meId;

  /// You chose not to share this board's stat (or paused sharing).
  final bool youKeepPrivate;

  /// Places gained since last week (negative = dropped). Null if unknown.
  int? movement(LeaderboardEntry e) {
    final before = lastWeekRanks[e.user.id];
    return before == null ? null : before - e.rank;
  }
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final DateTime Function() _clock = widget.clock ?? DateTime.now;
  late final FriendsRepository _friends =
      widget.friends ?? MockFriendsRepository(clock: _clock);
  late final StatsRepository _stats =
      widget.stats ?? MockStatsRepository(friends: _friends, clock: _clock);

  late final FamilyStore _familyStore =
      widget.familyStore ?? FamilyStore.instance;

  var _board = LeaderboardBoard.xp;

  /// Null = all friends.
  late CircleFamily? _family = widget.initialFamily;

  /// Keyed by [_key] so each family + board is only loaded once.
  final _cache = <String, Future<_BoardData>>{};

  String get _key => '${_family?.id ?? 'friends'}/${_board.name}';

  Future<_BoardData> _load() {
    final board = _board;
    final userIds = _family?.profileIds;
    return _cache.putIfAbsent(_key, () async {
      final now = _clock();
      final lastWeek = DateTime(now.year, now.month, now.day - 7);
      Future<List<LeaderboardEntry>> fetch(DateTime weekOf) {
        final metric = board.metric;
        return metric == null
            ? _stats.xpLeaderboard(weekOf: weekOf, userIds: userIds)
            : _stats.leaderboard(metric, weekOf: weekOf, userIds: userIds);
      }

      final results = await Future.wait([fetch(now), fetch(lastWeek)]);
      final me = await _friends.currentUser();
      final mine = widget.sharing?.settingsFor(me.id);
      final metric = board.metric;
      return _BoardData(
        entries: results[0],
        lastWeekRanks: {for (final e in results[1]) e.user.id: e.rank},
        meId: me.id,
        youKeepPrivate: mine != null &&
            (metric == null
                ? mine.isPaused(now)
                : !mine.isShared(metric, now)),
      );
    });
  }

  Future<void> _pickFamily() async {
    final choice = await showModalBottomSheet<_ScopeChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ScopeSheet(
        families: _familyStore.families,
        selected: _family,
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _family = choice.family);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'My stats',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MyStatsScreen(
                    friends: _friends, stats: _stats, clock: _clock),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: _ScopeButton(
                label: _family?.name ?? 'All friends',
                onTap: _pickFamily,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text('This week', style: text.headlineMedium)),
                  const Icon(Icons.timer_outlined,
                      size: 18, color: AppColors.inkSoft),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(weekResetLabel(_clock()), style: text.bodySmall),
                  ),
                ],
              ),
            ),
            _BoardPicker(
              selected: _board,
              onSelected: (b) => setState(() => _board = b),
            ),
            Expanded(
              child: FutureBuilder<_BoardData>(
                future: _load(),
                builder: (context, snapshot) {
                  final Widget child;
                  if (snapshot.hasError) {
                    child = _Message(
                      key: const ValueKey('error'),
                      text: "Couldn't load the leaderboard. "
                          'Check your connection and try again.',
                      onRetry: () => setState(() => _cache.remove(_key)),
                    );
                  } else if (!snapshot.hasData) {
                    child = const Center(
                      key: ValueKey('loading'),
                      child: CircularProgressIndicator(),
                    );
                  } else {
                    final family = _family;
                    child = _BoardView(
                      key: ValueKey(_key),
                      board: _board,
                      data: snapshot.data!,
                      // Only for a family with nobody else in it yet. A
                      // board can also be short because people keep a
                      // stat private; _BoardView explains that instead.
                      soloText: family == null || family.profileIds.isNotEmpty
                          ? null
                          : "It's just you in ${family.name} so far. "
                          'Invite people to start a leaderboard 🏁',
                    );
                  }
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: child,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAMILY PICKER — whose leaderboard: all friends or one of your families
// ---------------------------------------------------------------------------

class _ScopeButton extends StatelessWidget {
  const _ScopeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ChunkySurface(
        key: const ValueKey('scope-button'),
        color: AppColors.surface,
        edgeColor: AppColors.border,
        borderColor: AppColors.border,
        radius: AppRadius.chip,
        depth: AppDepth.chip,
        semanticLabel: 'Showing $label. Switch leaderboard',
        padding: const EdgeInsets.symmetric(horizontal: 14),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_rounded, size: 20, color: AppColors.ink),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: AppColors.ink, letterSpacing: 0),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded,
                  size: 22, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the sheet closes with. [family] null = all friends.
class _ScopeChoice {
  const _ScopeChoice(this.family);
  final CircleFamily? family;
}

class _ScopeSheet extends StatelessWidget {
  const _ScopeSheet({required this.families, required this.selected});

  final List<CircleFamily> families;

  /// Null = all friends.
  final CircleFamily? selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Whose leaderboard?', style: text.titleLarge),
            const SizedBox(height: 2),
            Text('Compare with all your friends or one family',
                style: text.bodySmall),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ScopeOption(
                      icon: Icons.public_rounded,
                      title: 'All friends',
                      subtitle: 'Everyone you’ve added',
                      selected: selected == null,
                      onTap: () =>
                          Navigator.of(context).pop(const _ScopeChoice(null)),
                    ),
                    for (final family in families) ...[
                      const SizedBox(height: 10),
                      _ScopeOption(
                        icon: Icons.groups_rounded,
                        title: family.name,
                        subtitle: family.memberCount == 1
                            ? 'Just you so far'
                            : '${family.memberCount} members',
                        selected: family.id == selected?.id,
                        onTap: () =>
                            Navigator.of(context).pop(_ScopeChoice(family)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ChunkySurface(
      color: selected ? AppColors.primaryTint : AppColors.surface,
      edgeColor: selected ? AppColors.primaryDark : AppColors.border,
      borderColor: selected ? AppColors.primary : AppColors.border,
      radius: AppRadius.card,
      depth: AppDepth.card,
      selected: selected,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall),
                Text(subtitle, style: text.bodySmall),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BOARD PICKER — horizontal row of chunky chips
// ---------------------------------------------------------------------------

class _BoardPicker extends StatelessWidget {
  const _BoardPicker({required this.selected, required this.onSelected});

  final LeaderboardBoard selected;
  final ValueChanged<LeaderboardBoard> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48 + AppDepth.chip + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        itemCount: LeaderboardBoard.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final board = LeaderboardBoard.values[i];
          final isSelected = board == selected;
          final fg = isSelected ? AppColors.ink : AppColors.inkSoft;
          return ChunkySurface(
            key: ValueKey('board-${board.name}'),
            color: isSelected ? board.color : AppColors.surface,
            edgeColor: isSelected ? board.edgeColor : AppColors.border,
            borderColor: isSelected ? null : AppColors.border,
            radius: AppRadius.chip,
            depth: AppDepth.chip,
            selected: isSelected,
            semanticLabel: '${board.label} leaderboard',
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onTap: () {
              onSelected(board);
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            },
            child: SizedBox(
              height: 48,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(board.icon, size: 20, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    board.label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: fg, letterSpacing: 0),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BOARD VIEW — caption, podium, nudge line, then everyone else
// ---------------------------------------------------------------------------

class _BoardView extends StatelessWidget {
  const _BoardView({
    super.key,
    required this.board,
    required this.data,
    this.soloText,
  });

  final LeaderboardBoard board;
  final _BoardData data;

  /// Shown instead of a one-person podium (e.g. a brand-new family).
  final String? soloText;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries;
    final soloText = this.soloText;
    final metric = board.metric;
    // You're always on a board unless you keep its stat private, so an
    // empty metric board means nobody here shares it.
    if (entries.isEmpty && metric != null) {
      return _Message(
        text: 'Nobody here shares their ${metric.label.toLowerCase()} yet 🔒'
            '${data.youKeepPrivate ? '\nTurn it on in Privacy to be the first.' : ''}',
      );
    }
    if (metric != null &&
        soloText == null &&
        entries.length == 1 &&
        entries.single.user.id == data.meId) {
      return _Message(
        text: "You're the only one here sharing your "
            '${metric.label.toLowerCase()} so far 🔒',
      );
    }
    if (soloText != null && entries.length < 2) {
      return _Message(text: soloText);
    }
    if (entries.isEmpty) {
      return const _Message(
          text: 'Add friends to start a leaderboard. '
              "It's more fun with company!");
    }
    final top = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(board.caption, style: text.bodySmall),
        const SizedBox(height: 16),
        _Podium(board: board, top: top, data: data),
        const SizedBox(height: 16),
        _NudgeLine(board: board, data: data),
        const SizedBox(height: 16),
        for (final e in rest) ...[
          _RankRow(board: board, entry: e, data: data),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PODIUM — 2nd / 1st / 3rd blocks that rise in
// ---------------------------------------------------------------------------

class _Medal {
  const _Medal(this.color, this.edge, this.blockHeight);
  final Color color;
  final Color edge;
  final double blockHeight;
}

const _medals = [
  _Medal(AppColors.gold, AppColors.goldDark, 112),
  _Medal(AppColors.silver, AppColors.silverDark, 80),
  _Medal(AppColors.bronze, AppColors.bronzeDark, 56),
];

class _Podium extends StatefulWidget {
  const _Podium({required this.board, required this.top, required this.data});

  final LeaderboardBoard board;
  final List<LeaderboardEntry> top;
  final _BoardData data;

  @override
  State<_Podium> createState() => _PodiumState();
}

class _PodiumState extends State<_Podium> with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rise.isAnimating || _rise.isCompleted) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    reduceMotion ? _rise.value = 1 : _rise.forward();
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Visual order: 2nd, 1st, 3rd. Bronze rises first, gold last.
    const order = [1, 0, 2];
    const starts = [0.3, 0.15, 0.0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final place in order)
          Expanded(
            child: place < widget.top.length
                ? _PodiumSpot(
              key: ValueKey('podium-${place + 1}'),
              board: widget.board,
              entry: widget.top[place],
              medal: _medals[place],
              isMe: widget.top[place].user.id == widget.data.meId,
              movement: widget.data.movement(widget.top[place]),
              rise: CurvedAnimation(
                parent: _rise,
                curve: Interval(starts[place], starts[place] + 0.7,
                    curve: Curves.easeOutBack),
              ),
            )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  const _PodiumSpot({
    super.key,
    required this.board,
    required this.entry,
    required this.medal,
    required this.isMe,
    required this.movement,
    required this.rise,
  });

  final LeaderboardBoard board;
  final LeaderboardEntry entry;
  final _Medal medal;
  final bool isMe;
  final int? movement;
  final Animation<double> rise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = entry.rank == 1 && medal.color == AppColors.gold;
    final value = board.format(entry.value);

    return Semantics(
      label: '${ordinal(entry.rank)} place, ${entry.user.displayName}, $value'
          '${movementPhrase(movement)}',
      container: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (first)
              const Icon(Icons.emoji_events_rounded,
                  color: AppColors.gold, size: 28),
            _Avatar(
              emoji: entry.user.avatarEmoji,
              size: first ? 68 : 56,
              ringColor: isMe ? AppColors.primary : medal.color,
            ),
            const SizedBox(height: 6),
            Text(
              entry.user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall,
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
            const SizedBox(height: 2),
            _Movement(delta: movement),
            const SizedBox(height: 8),
            // The block grows from the floor (and bounces a little).
            AnimatedBuilder(
              animation: rise,
              builder: (context, child) => ChunkySurface(
                color: medal.color,
                edgeColor: medal.edge,
                radius: AppRadius.chip,
                child: SizedBox(
                  height: math.max(0, medal.blockHeight * rise.value),
                  child: ClipRect(child: child),
                ),
              ),
              child: Center(
                child: Text(
                  '${entry.rank}',
                  style: text.headlineLarge?.copyWith(color: AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NUDGE LINE — how far you are from the next spot
// ---------------------------------------------------------------------------

class _NudgeLine extends StatelessWidget {
  const _NudgeLine({required this.board, required this.data});

  final LeaderboardBoard board;
  final _BoardData data;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      key: const ValueKey('nudge'),
      color: AppColors.surfaceSunken,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        nudgeMessage(
          board,
          data.entries,
          data.meId,
          youKeepPrivate: data.youKeepPrivate,
        ),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// Friendly one-liner about the gap to the person right above you.
///
/// [youKeepPrivate]: you're off this board because you don't share its stat.
String nudgeMessage(
  LeaderboardBoard board,
  List<LeaderboardEntry> entries,
  String meId, {
  bool youKeepPrivate = false,
}) {
  final i = entries.indexWhere((e) => e.user.id == meId);
  if (i == -1) {
    return youKeepPrivate
        ? "You keep this one private, so you're not on this board 🔒"
        : 'Sync your stats to join the race 🏁';
  }
  final me = entries[i];
  if (me.rank == 1) {
    return entries.length > 1 && entries[1].rank == 1
        ? "You're tied for first. Time for a tiebreaker 👀"
        : "You're #1 this week. Don't get comfy 👑";
  }
  final ahead = entries.lastWhere((e) => e.rank < me.rank);
  final gap = (ahead.value - me.value).abs().round();
  final name = ahead.user.displayName;
  return switch (board) {
    LeaderboardBoard.xp => '${formatThousands(gap)} XP to pass $name 👀',
    LeaderboardBoard.steps =>
    "You're ${formatThousands(gap)} steps behind $name 👀",
    LeaderboardBoard.sleep =>
    '${formatMinutes(gap)} more sleep a night to pass $name 😴',
    LeaderboardBoard.workout =>
    '${formatThousands(gap)} workout minutes to pass $name 💪',
    LeaderboardBoard.screenTime =>
    'Cut ${formatMinutes(gap)} a day to pass $name 📵',
  };
}

// ---------------------------------------------------------------------------
// RANK ROW — 4th place and below
// ---------------------------------------------------------------------------

class _RankRow extends StatelessWidget {
  const _RankRow({required this.board, required this.entry, required this.data});

  final LeaderboardBoard board;
  final LeaderboardEntry entry;
  final _BoardData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isMe = entry.user.id == data.meId;
    final movement = data.movement(entry);
    final value = board.format(entry.value);

    return Semantics(
      label: '${ordinal(entry.rank)} place, ${entry.user.displayName}, $value'
          '${movementPhrase(movement)}',
      container: true,
      excludeSemantics: true,
      child: ChunkyCard(
        key: ValueKey('row-${entry.user.id}'),
        color: isMe ? AppColors.primaryTint : AppColors.surface,
        borderColor: isMe ? AppColors.primary : AppColors.border,
        edgeColor: isMe ? AppColors.primaryDark : AppColors.border,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('${entry.rank}',
                  style: text.titleMedium?.copyWith(color: AppColors.inkSoft)),
            ),
            _Avatar(emoji: entry.user.avatarEmoji, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall),
                  Text('@${entry.user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: text.titleSmall),
                _Movement(delta: movement),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SMALL PIECES
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  const _Avatar({required this.emoji, required this.size, this.ringColor});

  final String emoji;
  final double size;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        shape: BoxShape.circle,
        border: ringColor == null
            ? Border.all(color: AppColors.border, width: 2)
            : Border.all(color: ringColor!, width: 3),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.48)),
    );
  }
}

/// ▲2 / ▼1 / – compared with last week.
class _Movement extends StatelessWidget {
  const _Movement({required this.delta});

  final int? delta;

  @override
  Widget build(BuildContext context) {
    final d = delta;
    final style = Theme.of(context).textTheme.labelSmall;
    if (d == null || d == 0) {
      return Text('–', style: style?.copyWith(color: AppColors.muted));
    }
    final up = d > 0;
    final color = up ? AppColors.primaryText : AppColors.redText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
            color: color, size: 20),
        Text('${d.abs()}', style: style?.copyWith(color: color)),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ChunkyButton(label: 'Try again', onPressed: onRetry, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FORMATTING
// ---------------------------------------------------------------------------

/// The week resets Monday 00:00 local time (see [startOfWeek]).
String weekResetLabel(DateTime now) {
  final start = startOfWeek(now);
  final next = DateTime(start.year, start.month, start.day + 7);
  final left = next.difference(now);
  if (left.inDays >= 1) {
    final d = left.inDays;
    return 'Resets in $d ${d == 1 ? 'day' : 'days'}';
  }
  if (left.inHours >= 1) {
    final h = left.inHours;
    return 'Resets in $h ${h == 1 ? 'hour' : 'hours'}';
  }
  return 'Resets in ${math.max(1, left.inMinutes)} min';
}

String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

String movementPhrase(int? delta) {
  if (delta == null || delta == 0) return '';
  final places = delta.abs() == 1 ? 'place' : 'places';
  return delta > 0
      ? ', up ${delta.abs()} $places since last week'
      : ', down ${delta.abs()} $places since last week';
}