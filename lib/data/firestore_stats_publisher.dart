import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Publishes the signed-in user's daily totals to `users/{uid}/daily/{yyyy-MM-dd}`,
/// where their accepted friends can read them (see firestore.rules).
///
/// Sharing is enforced here, before anything leaves the device:
/// - Only metrics the user shares are written. A hidden metric's key is
///   left out of the document, never written as 0.
/// - While sharing is paused, nothing is written and any published days are
///   deleted.
/// - Each call rewrites the last [windowDays] days, so a metric hidden
///   later disappears from documents that already had it.
///
/// Documents hold daily totals only. Nothing here logs values.
class FirestoreStatsPublisher {
  FirestoreStatsPublisher(
    this._db, {
    required this.uid,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final String uid;
  final DateTime Function() _clock;

  /// How many days back (today included) are kept in sync.
  static const windowDays = 14;

  /// Upper bounds for one day, matching firestore.rules. Larger values are
  /// clamped so one odd reading can't make the whole batch fail.
  static const maxValues = {
    StatMetric.steps: 200000,
    StatMetric.sleep: 1440,
    StatMetric.workout: 1440,
    StatMetric.calories: 20000,
    StatMetric.screenTime: 1440,
  };

  /// What to publish for [day] given the metrics in [shared]: `date` plus one
  /// key (the [StatMetric.name]) per shared metric. Null when nothing is shared.
  static Map<String, Object>? dayFields(
    DailyStats day,
    Set<StatMetric> shared,
  ) {
    if (shared.isEmpty) return null;
    return {
      'date': dateKey(day.date),
      for (final m in StatMetric.values)
        if (shared.contains(m)) m.name: m.valueOf(day).clamp(0, maxValues[m]!),
    };
  }

  /// Makes the last [windowDays] days match [days] and [settings]:
  /// shared days are written (replacing the whole document), everything else
  /// in the window is deleted.
  ///
  /// [unavailable] are metrics whose values aren't known (e.g. permission
  /// denied), so they're treated as not shared rather than published as 0.
  Future<void> publish(
    Iterable<DailyStats> days,
    SharingSettings settings, {
    Set<StatMetric> unavailable = const {},
  }) async {
    final now = _clock();
    final today = dateOnly(now);
    final shared = {
      for (final m in StatMetric.values)
        if (settings.isShared(m, now) && !unavailable.contains(m)) m,
    };
    final byDay = {for (final d in days) dateKey(d.date): d};
    final collection = _db.collection('users').doc(uid).collection('daily');

    final batch = _db.batch();
    for (var i = 0; i < windowDays; i++) {
      final key = dateKey(DateTime(today.year, today.month, today.day - i));
      final day = byDay[key];
      final fields = day == null ? null : dayFields(day, shared);
      final ref = collection.doc(key);
      if (fields == null) {
        batch.delete(ref);
      } else {
        batch.set(ref, {...fields, 'updatedAt': FieldValue.serverTimestamp()});
      }
    }
    await batch.commit();
  }
}
