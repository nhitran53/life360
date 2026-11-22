import 'dart:async';
import 'dart:math';

import '../models/models.dart';
import 'local_account_store.dart';
import 'mock_data.dart';
import 'profile_repository.dart';

/// Local profiles. The mock friends' usernames and friend codes count as
/// taken, so the "already taken" paths can be tried out.
///
/// In memory by default; [MockProfileRepository.persistent] keeps them on
/// the device so they survive an app restart.
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository({this._random}) : _store = null;

  MockProfileRepository._persistent(LocalAccountStore store)
    : _store = store,
      _random = null;

  /// Loads the profiles saved in [store].
  static Future<MockProfileRepository> persistent(
    LocalAccountStore store,
  ) async {
    final repo = MockProfileRepository._persistent(store);
    await repo._restore();
    return repo;
  }

  static const _storeKey = 'profiles';

  final LocalAccountStore? _store;
  final Random? _random;
  final _profiles = <String, UserProfile>{};
  final _goals = <String, DailyGoals>{};
  final _emails = <String, String>{};

  Iterable<UserProfile> get _everyone => [...mockAllUsers, ..._profiles.values];

  Future<void> _restore() async {
    final data = await _store?.load(_storeKey);
    if (data == null) return;
    for (final MapEntry(:key, :value)
        in (data['profiles'] as Map<String, dynamic>? ?? {}).entries) {
      _profiles[key] = UserProfile.fromJson(value as Map<String, dynamic>);
    }
    for (final MapEntry(:key, :value)
        in (data['goals'] as Map<String, dynamic>? ?? {}).entries) {
      _goals[key] = DailyGoals.fromJson(value as Map<String, dynamic>);
    }
    for (final MapEntry(:key, :value)
        in (data['emails'] as Map<String, dynamic>? ?? {}).entries) {
      _emails[key] = value as String;
    }
  }

  void _persist() {
    final store = _store;
    if (store == null) return;
    unawaited(
      store.save(_storeKey, {
        'profiles': {
          for (final MapEntry(:key, :value) in _profiles.entries)
            key: value.toJson(),
        },
        'goals': {
          for (final MapEntry(:key, :value) in _goals.entries)
            key: value.toJson(),
        },
        'emails': _emails,
      }),
    );
  }

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
    _persist();
    return profile;
  }

  @override
  Future<void> updateGoals(String uid, DailyGoals goals) async {
    _goals[uid] = goals;
    _persist();
  }

  @override
  Future<void> saveEmail(String uid, String email) async {
    _emails[uid] = normalizeEmail(email);
    _persist();
  }

  @override
  Future<String?> emailFor(String uid) async => _emails[uid];

  @override
  Future<void> deleteProfile(String uid) async {
    _profiles.remove(uid);
    _goals.remove(uid);
    _emails.remove(uid);
    _persist();
  }
}
