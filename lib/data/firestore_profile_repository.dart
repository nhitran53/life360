import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'profile_repository.dart';

/// [ProfileRepository] backed by Firestore.
///
/// Layout (see firestore.rules):
/// - `users/{uid}`: public profile (name, @username, avatar, friend code)
/// - `users/{uid}/private/goals`: daily goals, only the owner can read them
/// - `usernames/{username}` and `friendCodes/{code}`: `{uid}` claims that
///   keep both unique. They're written in the same transaction as the
///   profile, and the rules only accept a claim that matches it.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db, {this._random});

  final FirebaseFirestore _db;
  final Random? _random;

  /// How many random friend codes to try before giving up. With 31^6
  /// (~890 million) codes a clash is already very unlikely.
  static const _codeAttempts = 5;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _goals(String uid) =>
      _user(uid).collection('private').doc('goals');
  DocumentReference<Map<String, dynamic>> _username(String username) =>
      _db.collection('usernames').doc(username);
  DocumentReference<Map<String, dynamic>> _friendCode(String code) =>
      _db.collection('friendCodes').doc(code);

  @override
  Future<UserProfile?> profileFor(String uid) async {
    final snap = await _user(uid).get();
    final data = snap.data();
    if (data == null) return null;
    return UserProfile.fromJson({...data, 'id': uid});
  }

  @override
  Future<DailyGoals> goalsFor(String uid) async {
    final data = (await _goals(uid).get()).data();
    return data == null ? const DailyGoals() : DailyGoals.fromJson(data);
  }

  @override
  Future<bool> isUsernameAvailable(String username) async =>
      !(await _username(username).get()).exists;

  @override
  Future<UserProfile> createProfile({
    required String uid,
    required String displayName,
    required String username,
    required String avatarEmoji,
    DailyGoals goals = const DailyGoals(),
  }) async {
    final problem = usernameProblem(username);
    if (problem != null) throw ProfileException(problem);

    for (var attempt = 0; attempt < _codeAttempts; attempt++) {
      final code = generateFriendCode(_random);
      final profile = UserProfile(
        id: uid,
        displayName: displayName.trim(),
        username: username,
        avatarEmoji: avatarEmoji,
        friendCode: code,
      );
      final created = await _db.runTransaction<bool>((tx) async {
        // All reads first, as Firestore transactions require.
        final nameClaim = await tx.get(_username(username));
        final codeClaim = await tx.get(_friendCode(code));
        if (nameClaim.exists && nameClaim.data()?['uid'] != uid) {
          throw ProfileException('@$username was just taken. Try another one.');
        }
        if (codeClaim.exists) return false; // try another code

        final data = profile.toJson()
          ..remove('id')
          ..['createdAt'] = FieldValue.serverTimestamp();
        tx
          ..set(_username(username), {'uid': uid})
          ..set(_friendCode(code), {'uid': uid})
          ..set(_user(uid), data)
          ..set(_goals(uid), goals.toJson());
        return true;
      });
      if (created) return profile;
    }
    throw const ProfileException(
      "Couldn't create your friend code. Try again.",
    );
  }

  @override
  Future<void> updateGoals(String uid, DailyGoals goals) =>
      _goals(uid).set(goals.toJson());

  @override
  Future<void> deleteProfile(String uid) async {
    final profile = await profileFor(uid);
    final batch = _db.batch()..delete(_goals(uid));
    if (profile != null) {
      batch
        ..delete(_username(profile.username))
        ..delete(_friendCode(profile.friendCode))
        ..delete(_user(uid));
    }
    await batch.commit();
  }
}
