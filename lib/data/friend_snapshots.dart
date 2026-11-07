import '../models/models.dart';
import 'sharing_repository.dart';
import 'stats_repository.dart';

/// Loads what you can see of [friend] right now.
///
/// [stats] should be the sharing-filtered repository, so a friend's hidden
/// stats never leave it; [sharing] only tells the UI which ones to lock.
Future<FriendSnapshot> loadFriendSnapshot(
  UserProfile friend, {
  required StatsRepository stats,
  required SharingRepository sharing,
  required DateTime now,
}) async {
  final today = dateOnly(now);
  final settings = sharing.settingsFor(friend.id);
  final hidden = {
    for (final m in StatMetric.values)
      if (!settings.isShared(m, now)) m,
  };

  // Far enough back for any realistic streak in the mock data.
  final recent = await stats.dailyStats(
    friend.id,
    from: DateTime(today.year, today.month, today.day - 60),
    to: today,
  );
  final week = await stats.weeklySummary(friend.id, weekOf: now);

  // A streak is built from steps and workouts. With one of them private its
  // value reads as 0 here, so the streak only counts what they share.
  final streakVisible =
      !hidden.contains(StatMetric.steps) ||
      !hidden.contains(StatMetric.workout);

  return FriendSnapshot(
    user: friend,
    today: recent.where((d) => d.date == today).firstOrNull,
    week: week,
    streak: streakVisible ? currentStreak(recent, today: today) : null,
    hidden: hidden,
  );
}
