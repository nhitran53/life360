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
class PublishedSharingRepository extends ChangeNotifier
    implements SharingRepository {
  PublishedSharingRepository(this.inner) {
    inner.addListener(notifyListeners);
  }

  final SharingRepository inner;

  final _published = <String, Set<StatMetric>>{};

  /// Far enough ahead that a friend with nothing published is always paused.
  static final _indefinitely = DateTime.utc(9999);

  /// Remembers that [userId]'s published days contain [metrics], replacing
  /// what was recorded before. Doesn't notify: it's called while reading.
  void record(String userId, Set<StatMetric> metrics) {
    _published[userId] = Set.unmodifiable(metrics);
  }

  @override
  bool get isLoaded => inner.isLoaded;

  @override
  Future<void> refresh() => inner.refresh();

  @override
  Future<void> update(String userId, SharingSettings settings) =>
      inner.update(userId, settings);

  @override
  SharingSettings settingsFor(String userId) {
    final metrics = _published[userId];
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
