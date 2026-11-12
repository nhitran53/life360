import 'package:flutter/material.dart';

import '../data/league_service.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'chunky.dart';

extension LeagueColors on League {
  Color get color => switch (this) {
    League.bronze => AppColors.bronze,
    League.silver => AppColors.silver,
    League.gold => AppColors.gold,
    League.platinum => AppColors.blue,
    League.diamond => AppColors.purple,
  };

  Color get edgeColor => switch (this) {
    League.bronze => AppColors.bronzeDark,
    League.silver => AppColors.silverDark,
    League.gold => AppColors.goldDark,
    League.platinum => AppColors.blueDark,
    League.diamond => AppColors.purpleDark,
  };
}

/// One encouraging line about where you stand this week.
String leagueMessage(LeagueStanding s) {
  final rank = s.rank;
  if (rank == null) {
    return "Turn sharing back on to compete in this week's league.";
  }
  if (s.groupSize < 2) return 'Add friends to start climbing the leagues 🏁';
  return switch (s.zone) {
    LeagueMove.up =>
      "You're in the promotion zone 🚀 "
          'Finish here to reach ${s.league.after(LeagueMove.up).label}!',
    LeagueMove.down =>
      "You're in the drop zone. One good workout could pull you out 💪",
    LeagueMove.stay when s.league.isTop =>
      "You're in the top league 💎 Hold your spot!",
    LeagueMove.stay => _safeLine(rank, s.groupSize),
  };
}

String _safeLine(int rank, int groupSize) {
  final zone = leagueZoneSize(groupSize);
  final whoMovesUp = zone == 1 ? 'The winner moves' : 'Top $zone move';
  return '$whoMovesUp up on Monday. '
      "You're ${ordinal(rank)} right now.";
}

/// Your league this week, shown on the Overall XP leaderboard.
class LeagueCard extends StatelessWidget {
  const LeagueCard({super.key, required this.standing});

  final LeagueStanding standing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final league = standing.league;
    final lastWeek = standing.lastWeek;
    return ChunkySurface(
      key: const ValueKey('league-card'),
      color: AppColors.surface,
      borderColor: league.color,
      edgeColor: league.edgeColor,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: league.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_rounded, color: league.edgeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${league.emoji} ${league.label} League',
                  style: text.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(leagueMessage(standing), style: text.bodySmall),
                if (lastWeek == LeagueMove.up ||
                    lastWeek == LeagueMove.down) ...[
                  const SizedBox(height: 6),
                  Text(
                    lastWeek == LeagueMove.up
                        ? 'Promoted last week 🎉'
                        : 'Moved down last week. New week, fresh start!',
                    key: const ValueKey('league-last-week'),
                    style: text.labelMedium?.copyWith(
                      color: lastWeek == LeagueMove.up
                          ? AppColors.primaryText
                          : AppColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
