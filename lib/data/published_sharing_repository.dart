import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'sharing_repository.dart';

/// [SharingRepository] that knows what friends share from the stats they
/// published, since their settings are private to them.
///
/// The signed-in user's settings come straight from [inner]. For anyone else,
/// once [record] has been told which metrics their published days contain,
/// exactly those are shared. A metric with a key is shared (even at 0); a
/// metric without one is not. Until something is recorded for a user, [inner]
/// answers (the private defaults for real friends).
///
/// A friend with nothing published at all reads as paused: all we can know is
/// that they paused, hid everything, or haven't synced yet, and none of those
/// should put them on a board.
///
/// Lookups of the same friend can finish in any order, so [record] never
/// lets the finishing order decide: the lookup that started last is the
/// truth, and one that started earlier can't overwrite it.
class PublishedSharingRepository extends ChangeNotifier
    implements SharingRepository {
  PublishedSharingRepository(this.inner) {
    inner.addListener(notifyListeners);
  }

  final SharingRepository inner;

  final _published = <String, ({int lookup, Set<StatMetric> metrics})>{};
  int _lastLookup = 0;

  /// Far enough ahead that a friend with nothing published is always paused.
  static final _indefinitely = DateTime.utc(9999);

  /// Numbers a lookup of what a friend shares; call it when the lookup
  /// starts and pass the result to [record].
  int startLookup() => ++_lastLookup;

  /// Remembers that [userId]'s current published days contain [metrics], as
  /// found by [lookup] (from [startLookup]). A lookup that started before the
  /// one already recorded is ignored. Doesn't notify: it's called while
  /// reading.
  ///
  /// A lookup that failed must not be recorded as `{}`: record nothing, and
  /// the previous answer (or the inner repository's default) stays.
  void record(String userId, Set<StatMetric> metrics, int lookup) {
    final current = _published[userId];
    if (current != null && lookup < current.lookup) return;
    _published[userId] = (lookup: lookup, metrics: Set.unmodifiable(metrics));
  }

  /// Whether a lookup has been recorded for [userId].
  bool hasRecorded(String userId) => _published.containsKey(userId);

  @override
  bool get isLoaded => inner.isLoaded;

  @override
  Future<void> refresh() => inner.refresh();

  @override
  Future<void> update(String userId, SharingSettings settings) =>
      inner.update(userId, settings);

  @override
  SharingSettings settingsFor(String userId) {
    final metrics = _published[userId]?.metrics;
    if (metrics == null) return inner.settingsFor(userId);
    return SharingSettings(
      hidden: {
        for (final m in StatMetric.values)
          if (!metrics.contains(m)) m,
      },
      pausedUntil: metrics.isEmpty ? _indefinitely : null,
    );
  }

  @override
  void dispose() {
    inner.removeListener(notifyListeners);
    super.dispose();
  }
}
