import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/stat_colors.dart';
import '../utils/format.dart';

// ---------------------------------------------------------------------------
// Pieces shared by Friends' Stats and a friend's profile.
// ---------------------------------------------------------------------------

/// A stat's value as people read it: "8,240", "45 min", "7h 05m".
String formatStat(StatMetric metric, num value) {
  final n = value.round();
  return switch (metric) {
    StatMetric.steps => formatThousands(n),
    StatMetric.workout => '$n min',
    StatMetric.calories => '${formatThousands(n)} kcal',
    StatMetric.sleep || StatMetric.screenTime => formatMinutes(n),
  };
}

/// Shown in place of a value the friend keeps private.
const lockedValue = '🔒';

/// Emoji in a soft circle (placeholder until real profile pictures).
class EmojiAvatar extends StatelessWidget {
  const EmojiAvatar({super.key, required this.emoji, this.size = 48});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSunken,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// 🔥 and a day count, or 🔒 when the streak's stats are private.
class StreakPill extends StatelessWidget {
  const StreakPill({super.key, required this.streak});

  /// Null when hidden.
  final int? streak;

  @override
  Widget build(BuildContext context) {
    final streak = this.streak;
    final text = Theme.of(context).textTheme;
    final hidden = streak == null;

    return Semantics(
      label: hidden ? 'Streak is private' : '$streak day streak',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: hidden
              ? AppColors.surfaceSunken
              : AppColors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          hidden ? '🔥 $lockedValue' : '🔥 $streak',
          style: text.labelLarge?.copyWith(
            color: hidden ? AppColors.inkSoft : AppColors.orangeDark,
          ),
        ),
      ),
    );
  }
}

/// A stat's emoji, value and label in its own color, e.g. 👟 8,240 steps.
class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.metric,
    required this.value,
    required this.label,
  });

  final StatMetric metric;

  /// Null shows 🔒.
  final num? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final value = this.value;
    final shown = value == null ? lockedValue : formatStat(metric, value);

    return Semantics(
      label: value == null
          ? '${metric.label} is private'
          : '$shown ${metric.label.toLowerCase()}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${metric.emoji} $shown',
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(
              color: value == null ? AppColors.inkSoft : metric.edgeColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: text.labelMedium?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
