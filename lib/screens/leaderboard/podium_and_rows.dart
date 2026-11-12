part of '../leaderboard_screen.dart';

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
