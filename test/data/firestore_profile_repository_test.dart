import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/firestore_profile_repository.dart';
import 'package:life360/data/profile_repository.dart';
import 'package:life360/models/models.dart';

// Checks the document layout and uniqueness logic. Security rules aren't
// enforced by the fake: see firestore.rules for those.
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreProfileRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreProfileRepository(db, random: Random(7));
  });

  Future<UserProfile> createNhi({String uid = 'u1'}) => repo.createProfile(
    uid: uid,
    displayName: ' Nhi ',
    username: 'nhi',
    avatarEmoji: '🦊',
    goals: const DailyGoals(steps: 10000),
  );

  test('creates the profile, goals and both claims', () async {
    final profile = await createNhi();

    final user = (await db.doc('users/u1').get()).data()!;
    expect(user['displayName'], 'Nhi');
    expect(user['username'], 'nhi');
    expect(user['friendCode'], profile.friendCode);
    expect(user.containsKey('id'), isFalse);
    expect(user['createdAt'], isNotNull);

    expect((await db.doc('usernames/nhi').get()).data(), {'uid': 'u1'});
    expect((await db.doc('friendCodes/${profile.friendCode}').get()).data(), {
      'uid': 'u1',
    });

    expect(await repo.profileFor('u1'), profile);
    expect((await repo.profileFor('u1'))!.displayName, 'Nhi');
    expect((await repo.goalsFor('u1')).steps, 10000);
  });

  test('missing profile and goals', () async {
    expect(await repo.profileFor('nobody'), isNull);
    expect(await repo.goalsFor('nobody'), const DailyGoals());
  });

  test('usernames are unique', () async {
    expect(await repo.isUsernameAvailable('nhi'), isTrue);
    await createNhi();
    expect(await repo.isUsernameAvailable('nhi'), isFalse);

    expect(
      () => repo.createProfile(
        uid: 'u2',
        displayName: 'Someone',
        username: 'nhi',
        avatarEmoji: '🐼',
      ),
      throwsA(isA<ProfileException>()),
    );
    expect(await repo.profileFor('u2'), isNull);
  });

  test('rejects invalid usernames before writing', () async {
    expect(
      () => repo.createProfile(
        uid: 'u1',
        displayName: 'Nhi',
        username: 'No Spaces',
        avatarEmoji: '🦊',
      ),
      throwsA(isA<ProfileException>()),
    );
    expect((await db.collection('usernames').get()).docs, isEmpty);
  });

  test('picks another friend code when one is taken', () async {
    // The same seed produces the same first code, so claim it ahead.
    final firstCode = generateFriendCode(Random(7));
    await db.doc('friendCodes/$firstCode').set({'uid': 'someone-else'});

    final profile = await createNhi();
    expect(profile.friendCode, isNot(firstCode));
  });

  test('updates goals', () async {
    await createNhi();
    await repo.updateGoals('u1', const DailyGoals(workoutMinutes: 45));
    expect((await repo.goalsFor('u1')).workoutMinutes, 45);
  });

  test('delete removes everything and frees the username', () async {
    final profile = await createNhi();
    await db.doc('users/u1/daily/2026-03-12').set({'date': '2026-03-12'});
    await repo.deleteProfile('u1');

    expect((await db.doc('users/u1/daily/2026-03-12').get()).exists, isFalse);
    expect((await db.doc('users/u1').get()).exists, isFalse);
    expect((await db.doc('users/u1/private/goals').get()).exists, isFalse);
    expect((await db.doc('usernames/nhi').get()).exists, isFalse);
    expect(
      (await db.doc('friendCodes/${profile.friendCode}').get()).exists,
      isFalse,
    );
    expect(await repo.isUsernameAvailable('nhi'), isTrue);
  });
}
