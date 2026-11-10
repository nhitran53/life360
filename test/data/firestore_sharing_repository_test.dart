import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/account_session.dart';
import 'package:life360/data/firestore_profile_repository.dart';
import 'package:life360/data/firestore_sharing_repository.dart';
import 'package:life360/data/mock_auth_repository.dart';
import 'package:life360/data/mock_profile_repository.dart';
import 'package:life360/models/models.dart';

// Checks the document layout and caching. Security rules aren't enforced by
// the fake: see firestore.rules for those.
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreSharingRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreSharingRepository(db, uid: 'u1');
  });

  test('sleep and screen time are private before anything is saved', () async {
    expect(repo.settingsFor('u1'), const SharingSettings());
    await repo.load();
    expect(repo.settingsFor('u1').hidden, SharingSettings.defaultHidden);
  });

  test('load saves the default settings when there is no document', () async {
    await repo.load();
    final doc = await db.doc('users/u1/private/settings').get();
    expect(doc.data(), {
      'hidden': ['sleep', 'screenTime'],
      'pausedUntil': null,
    });
  });

  test('load keeps settings that were already saved', () async {
    await db.doc('users/u1/private/settings').set({
      'hidden': ['steps'],
      'pausedUntil': null,
    });
    await repo.load();
    expect(repo.settingsFor('u1').hidden, {StatMetric.steps});
    final doc = await db.doc('users/u1/private/settings').get();
    expect(doc.data()!['hidden'], ['steps']);
  });

  test('a failed default create leaves the settings not loaded', () async {
    final failing = FirestoreSharingRepository(_NoCreateDb(), uid: 'u1');
    await failing.load();
    expect(failing.isLoaded, isFalse);
  });

  test('isLoaded is false until the saved settings were read', () async {
    expect(repo.isLoaded, isFalse);
    var notified = 0;
    repo.addListener(() => notified++);
    await repo.load(); // no document yet: the defaults are the real settings
    expect(repo.isLoaded, isTrue);
    expect(notified, 1);
  });

  test(
    'isLoaded stays false when the load fails, and after a failed save',
    () async {
      final failing = FirestoreSharingRepository(_BrokenDb(), uid: 'u1');
      await failing.load();
      expect(failing.isLoaded, isFalse);
      await expectLater(
        failing.update('u1', const SharingSettings(hidden: {})),
        throwsA(isA<FirebaseException>()),
      );
      expect(failing.isLoaded, isFalse);
    },
  );

  test('saving a change counts as loaded', () async {
    await repo.update('u1', const SharingSettings(hidden: {}));
    expect(repo.isLoaded, isTrue);
  });

  test('update saves to users/{uid}/private/settings and notifies', () async {
    var notified = 0;
    repo.addListener(() => notified++);
    final pause = DateTime(2026, 3, 12, 9);
    final settings = const SharingSettings(
      hidden: {StatMetric.steps, StatMetric.sleep},
    ).withPause(pause);

    await repo.update('u1', settings);

    expect(repo.settingsFor('u1'), settings);
    expect(notified, 1);
    final data = (await db.doc('users/u1/private/settings').get()).data()!;
    expect(data.keys.toSet(), {'hidden', 'pausedUntil'});
    expect(data['hidden'], ['steps', 'sleep']);
    // A timestamp, so firestore.rules can compare it with the request time.
    expect(data['pausedUntil'], Timestamp.fromDate(pause));
    final later = FirestoreSharingRepository(db, uid: 'u1');
    await later.load();
    expect(later.settingsFor('u1'), settings);

    // Same value again: nothing to save or announce.
    await repo.update('u1', settings);
    expect(notified, 1);
  });

  test('a new repository loads what was saved', () async {
    await repo.update(
      'u1',
      const SharingSettings(hidden: {StatMetric.calories}),
    );

    final later = FirestoreSharingRepository(db, uid: 'u1');
    var notified = 0;
    later.addListener(() => notified++);
    await later.load();

    expect(later.settingsFor('u1').hidden, {StatMetric.calories});
    expect(notified, 1);
  });

  test('a document without a hidden list keeps the private defaults', () async {
    await db.doc('users/u1/private/settings').set({'pausedUntil': null});
    await repo.load();
    expect(repo.settingsFor('u1').hidden, SharingSettings.defaultHidden);
  });

  test('a slow load does not overwrite a change made meanwhile', () async {
    await db
        .doc('users/u1/private/settings')
        .set(const SharingSettings(hidden: {StatMetric.steps}).toJson());
    final loading = repo.load();
    await repo.update('u1', const SharingSettings(hidden: {}));
    await loading;
    expect(repo.settingsFor('u1').hidden, isEmpty);
  });

  test("other people's settings are never read: defaults apply", () async {
    await db
        .doc('users/u2/private/settings')
        .set(const SharingSettings(hidden: {}).toJson());
    await repo.load();
    expect(repo.settingsFor('u2'), const SharingSettings());
    expect(
      () => repo.update('u2', const SharingSettings(hidden: {})),
      throwsArgumentError,
    );
  });

  test('a failed save puts the previous settings back', () async {
    final failing = FirestoreSharingRepository(_BrokenDb(), uid: 'u1');
    await failing.load(); // an unreadable document keeps the defaults
    expect(failing.settingsFor('u1'), const SharingSettings());

    var notified = 0;
    failing.addListener(() => notified++);
    await expectLater(
      failing.update('u1', const SharingSettings(hidden: {})),
      throwsA(isA<FirebaseException>()),
    );
    expect(failing.settingsFor('u1'), const SharingSettings());
    expect(notified, 2); // shown, then reverted
  });

  test(
    'an older ISO-string pause is read, then rewritten as a timestamp',
    () async {
      final pause = DateTime.utc(2026, 3, 12, 9);
      await db.doc('users/u1/private/settings').set({
        'hidden': ['sleep'],
        'pausedUntil': pause.toIso8601String(),
      });

      await repo.load();

      expect(repo.settingsFor('u1').pausedUntil, pause.toLocal());
      final data = (await db.doc('users/u1/private/settings').get()).data()!;
      expect(data['pausedUntil'], Timestamp.fromDate(pause));
    },
  );

  test(
    'refresh picks up a change saved elsewhere and announces it once',
    () async {
      await repo.load();
      final other = FirestoreSharingRepository(db, uid: 'u1');
      await other.update(
        'u1',
        const SharingSettings(hidden: {StatMetric.steps}),
      );
      var notified = 0;
      repo.addListener(() => notified++);

      await repo.refresh();
      expect(repo.settingsFor('u1').hidden, {StatMetric.steps});
      expect(notified, 1);

      await repo.refresh(); // unchanged: nothing to announce
      expect(notified, 1);
    },
  );

  test('a slow refresh does not overwrite a change made meanwhile', () async {
    await repo.load();
    await db
        .doc('users/u1/private/settings')
        .set(const SharingSettings(hidden: {StatMetric.steps}).toJson());
    final refreshing = repo.refresh();
    await repo.update('u1', const SharingSettings(hidden: {}));
    await refreshing;
    expect(repo.settingsFor('u1').hidden, isEmpty);
  });

  test('deleting the profile deletes the sharing settings', () async {
    final profiles = FirestoreProfileRepository(db);
    await profiles.createProfile(
      uid: 'u1',
      displayName: 'Nhi',
      username: 'nhi',
      avatarEmoji: '🦊',
    );
    await repo.update('u1', const SharingSettings(hidden: {}));
    await repo.update('u1', const SharingSettings(hidden: {}).withPause(null));
    expect((await db.doc('users/u1/private/settings').get()).exists, isTrue);

    await profiles.deleteProfile('u1');

    expect((await db.doc('users/u1/private/settings').get()).exists, isFalse);
    expect((await db.doc('users/u1/private/goals').get()).exists, isFalse);
  });

  test(
    'AccountSession builds sharing for the signed-in profile only',
    () async {
      final auth = MockAuthRepository();
      final made = <String>[];
      final session = AccountSession(
        auth: auth,
        profiles: MockProfileRepository(),
        sharingFor: (me) {
          made.add(me.username);
          return FirestoreSharingRepository(db, uid: me.id);
        },
      );
      addTearDown(() {
        session.dispose();
        auth.dispose();
      });
      await Future<void>.delayed(Duration.zero);
      expect(session.sharing, isNull);

      await auth.signUpWithEmail('nhi@example.com', 'password1');
      await Future<void>.delayed(Duration.zero);
      expect(session.sharing, isNull); // no profile yet

      await session.completeOnboarding(
        displayName: 'Nhi',
        username: 'nhi',
        avatarEmoji: '🦊',
        goals: const DailyGoals(),
      );
      expect(session.sharing, isNotNull);
      expect(made, ['nhi']);

      await session.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(session.sharing, isNull);
    },
  );
}

class _BrokenDb extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
}

/// Reads work, but creating the default document fails.
class _NoCreateDb extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async =>
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
}
