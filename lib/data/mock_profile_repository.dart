import 'dart:math';

import '../models/models.dart';
import 'mock_data.dart';
import 'profile_repository.dart';

/// In-memory profiles. The mock friends' usernames and friend codes count
/// as taken, so the "already taken" paths can be tried out.
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository({this._random});

  final Random? _random;
  final _profiles = <String, UserProfile>{};
  final _goals = <String, DailyGoals>{};

  Iterable<UserProfile> get _everyone => [...mockAllUsers, ..._profiles.values];

  @override
  Future<UserProfile?> profileFor(String uid) async => _profiles[uid];

  @override
  Future<DailyGoals> goalsFor(String uid) async =>
      _goals[uid] ?? const DailyGoals();

  @override
  Future<bool> isUsernameAvailable(String username) async =>
      !_everyone.any((p) => p.username == username);

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
    if (!await isUsernameAvailable(username)) {
      throw ProfileException('@$username was just taken. Try another one.');
    }
    final taken = {for (final p in _everyone) p.friendCode};
    String code;
    do {
      code = generateFriendCode(_random);
    } while (taken.contains(code));

    final profile = UserProfile(
      id: uid,
      displayName: displayName.trim(),
      username: username,
      avatarEmoji: avatarEmoji,
      friendCode: code,
    );
    _profiles[uid] = profile;
    _goals[uid] = goals;
    return profile;
  }

  @override
  Future<void> updateGoals(String uid, DailyGoals goals) async {
    _goals[uid] = goals;
  }

  @override
  Future<void> deleteProfile(String uid) async {
    _profiles.remove(uid);
    _goals.remove(uid);
  }
}
