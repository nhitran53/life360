import 'package:flutter/material.dart';

import '../models/rewards.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'chunky.dart';

/// The emoji shown for each [RewardBadge].
extension RewardBadgeEmoji on RewardBadge {
  String get emoji => switch (this) {
    RewardBadge.firstActiveDay => '👟',
    RewardBadge.threeDayStreak => '🔥',
    RewardBadge.sevenDayStreak => '🏅',
    RewardBadge.workoutWeek => '💪',
    RewardBadge.tenKDay => '🚶',
    RewardBadge.powerHour => '⏱️',
  };
}

/// A small row of earned badges, or a nudge to earn the first one.
class BadgeRow extends StatelessWidget {
  const BadgeRow({super.key, required this.badges});

  final List<RewardBadge> badges;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (badges.isEmpty) {
      return Text(
        'No badges yet. Hit a steps or workout goal to earn your first 🏅',
        style: text.bodySmall,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final badge in badges)
          Semantics(
            container: true,
            label: '${badge.title} badge. ${badge.description}',
            child: ExcludeSemantics(
              child: ChunkySurface(
                key: ValueKey('badge-${badge.name}'),
                color: AppColors.gold.withValues(alpha: 0.15),
                edgeColor: AppColors.gold.withValues(alpha: 0.5),
                borderColor: AppColors.gold,
                radius: AppRadius.chip,
                depth: AppDepth.chip,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(badge.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(badge.title, style: text.labelMedium),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
