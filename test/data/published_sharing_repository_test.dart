import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/published_sharing_repository.dart';
import 'package:life360/data/sharing_repository.dart';
import 'package:life360/models/models.dart';

void main() {
  final now = DateTime(2026, 3, 12, 15);
  late MockSharingRepository inner;
  late PublishedSharingRepository repo;

  setUp(() {
    inner = MockSharingRepository(
      initial: {
        'me': const SharingSettings(hidden: {StatMetric.steps}),
      },
    );
    repo = PublishedSharingRepository(inner);
  });

  test('your own settings and anyone not recorded come from the inner one', () {
    expect(repo.settingsFor('me'), inner.settingsFor('me'));
    expect(repo.settingsFor('friend'), const SharingSettings());
  });

  test('a recorded friend shares exactly the published metrics', () {
    repo.record('friend', {StatMetric.sleep, StatMetric.steps});
    final settings = repo.settingsFor('friend');
    expect(settings.isShared(StatMetric.sleep, now), isTrue);
    expect(settings.isShared(StatMetric.steps, now), isTrue);
    expect(settings.isShared(StatMetric.workout, now), isFalse);
    expect(settings.isPaused(now), isFalse);
  });

  test('a friend with nothing published reads as paused and hides all', () {
    repo.record('friend', const {});
    final settings = repo.settingsFor('friend');
    expect(settings.isPaused(now), isTrue);
    for (final m in StatMetric.values) {
      expect(settings.isShared(m, now), isFalse);
    }
  });

  test('a later record replaces the earlier one', () {
    repo.record('friend', {StatMetric.sleep});
    repo.record('friend', {StatMetric.steps});
    expect(repo.settingsFor('friend').isShared(StatMetric.sleep, now), isFalse);
  });

  test('update and listeners go through to the inner repository', () async {
    var notified = 0;
    repo.addListener(() => notified++);
    await repo.update('me', const SharingSettings(hidden: {}));
    expect(inner.settingsFor('me').hidden, isEmpty);
    expect(notified, 1);
    expect(repo.isLoaded, isTrue);
  });
}
