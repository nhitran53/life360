import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/models.dart';
import 'auth_repository.dart';
import 'profile_repository.dart';

enum AccountStatus {
  /// Checking whether someone is already signed in.
  loading,
  signedOut,

  /// Signed in, but hasn't picked a username yet.
  needsProfile,
  ready,
}

/// Who's signed in and their profile. The app listens to this to decide
/// between the welcome screen, onboarding and the app itself.
class AccountSession extends ChangeNotifier {
  AccountSession({required this.auth, required this.profiles}) {
    _sub = auth.authStateChanges().listen(_onAuthChanged);
  }

  final AuthRepository auth;
  final ProfileRepository profiles;
  late final StreamSubscription<AuthUser?> _sub;

  AccountStatus _status = AccountStatus.loading;
  AccountStatus get status => _status;

  AuthUser? _user;
  AuthUser? get user => _user;

  UserProfile? _profile;

  /// Set when [status] is [AccountStatus.ready].
  UserProfile? get profile => _profile;

  DailyGoals _goals = const DailyGoals();
  DailyGoals get goals => _goals;

  /// Bumped on every auth change so a slow profile load for an old user
  /// can't overwrite a newer one.
  var _generation = 0;
  var _disposed = false;

  Future<void> _onAuthChanged(AuthUser? user) async {
    final generation = ++_generation;
    _user = user;
    if (user == null) {
      _profile = null;
      _goals = const DailyGoals();
      _set(AccountStatus.signedOut);
      return;
    }
    final profile = await profiles.profileFor(user.uid);
    final goals = await profiles.goalsFor(user.uid);
    if (generation != _generation || _disposed) return;
    _profile = profile;
    _goals = goals;
    _set(profile == null ? AccountStatus.needsProfile : AccountStatus.ready);
  }

  void _set(AccountStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  /// Saves the onboarding answers and moves to [AccountStatus.ready].
  Future<void> completeOnboarding({
    required String displayName,
    required String username,
    required String avatarEmoji,
    required DailyGoals goals,
  }) async {
    final user = _user;
    if (user == null) throw StateError('Nobody is signed in');
    _profile = await profiles.createProfile(
      uid: user.uid,
      displayName: displayName,
      username: username,
      avatarEmoji: avatarEmoji,
      goals: goals,
    );
    _goals = goals;
    _set(AccountStatus.ready);
  }

  Future<void> updateGoals(DailyGoals goals) async {
    final user = _user;
    if (user == null) return;
    await profiles.updateGoals(user.uid, goals);
    _goals = goals;
    notifyListeners();
  }

  Future<void> signOut() => auth.signOut();

  /// Deletes the user's data, then the account itself (App Store rule:
  /// apps with accounts must let people delete them in the app).
  ///
  /// Checks for a recent sign-in first, so a refused delete can't leave an
  /// account whose data is already gone.
  Future<void> deleteAccount() async {
    final user = _user;
    if (user == null) return;
    if (!auth.signedInRecently) {
      throw const AuthException(
        AuthException.requiresRecentLogin,
        'For safety, log out and back in, then try again.',
      );
    }
    await profiles.deleteProfile(user.uid);
    await auth.deleteAccount();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub.cancel();
    super.dispose();
  }
}

/// Makes the [AccountSession] available below it. Screens that work
/// without an account (e.g. in tests) use [maybeOf].
class AccountScope extends InheritedNotifier<AccountSession> {
  const AccountScope({
    super.key,
    required AccountSession session,
    required super.child,
  }) : super(notifier: session);

  static AccountSession? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier;

  static AccountSession of(BuildContext context) {
    final session = maybeOf(context);
    assert(session != null, 'No AccountScope above this widget');
    return session!;
  }
}
