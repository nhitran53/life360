import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/family_store.dart';
import '../data/friends_repository.dart';
import '../data/league_service.dart';
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
import '../widgets/league_card.dart';
import 'my_stats_screen.dart';

part 'leaderboard/scope_picker.dart';
part 'leaderboard/podium_and_rows.dart';

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

  /// Your league, between all your friends. Loaded the first time the
  /// Overall XP board is shown for all friends.
  late final Future<LeagueStanding> _league = LeagueService(
    stats: _stats,
    friends: _friends,
    clock: _clock,
  ).standing();

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
                      // Leagues are between all your friends, so they only
                      // show on the friends-wide XP board.
                      leagueCard: _board == LeaderboardBoard.xp &&
                              family == null
                          ? _LeagueSlot(standing: _league)
                          : null,
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
    this.leagueCard,
  });

  final LeaderboardBoard board;
  final _BoardData data;

  /// Shown above the podium (Overall XP, all friends).
  final Widget? leagueCard;

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
    final leagueCard = this.leagueCard;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (leagueCard != null) ...[leagueCard, const SizedBox(height: 16)],
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

/// The league card once [standing] loads. Nothing while loading or if it
/// fails: the leaderboard itself is what matters on this screen.
class _LeagueSlot extends StatelessWidget {
  const _LeagueSlot({required this.standing});

  final Future<LeagueStanding> standing;

  @override
  Widget build(BuildContext context) => FutureBuilder<LeagueStanding>(
    future: standing,
    builder: (context, snapshot) {
      final data = snapshot.data;
      return data == null ? const SizedBox.shrink() : LeagueCard(standing: data);
    },
  );
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

String movementPhrase(int? delta) {
  if (delta == null || delta == 0) return '';
  final places = delta.abs() == 1 ? 'place' : 'places';
  return delta > 0
      ? ', up ${delta.abs()} $places since last week'
      : ', down ${delta.abs()} $places since last week';
}
