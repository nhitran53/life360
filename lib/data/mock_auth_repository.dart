import 'dart:async';

import '../models/models.dart';
import 'auth_repository.dart';

/// In-memory accounts, so the sign-in flow works before Firebase is set up.
/// Everything is forgotten when the app restarts.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.socialSignInCancelled = false});

  /// Makes Google/Apple behave as if the user closed the sheet (for tests).
  bool socialSignInCancelled;

  final _controller = StreamController<AuthUser?>.broadcast();
  final _accounts = <String, _Account>{}; // by lowercase email
  var _nextId = 0;
  AuthUser? _current;

  @override
  AuthUser? get currentUser => _current;

  /// Set to false to try the "log in again first" path (for tests).
  bool recentLogin = true;

  @override
  bool get signedInRecently => _current != null && recentLogin;

  @override
  Stream<AuthUser?> authStateChanges() {
    // Subscribes to changes the moment someone listens, so nothing that
    // happens right after can be missed (an async* generator could).
    StreamSubscription<AuthUser?>? changes;
    late final StreamController<AuthUser?> out;
    out = StreamController<AuthUser?>(
      onListen: () {
        out.add(_current);
        changes = _controller.stream.listen(out.add);
      },
      onCancel: () => changes?.cancel(),
    );
    return out.stream;
  }

  void _setCurrent(AuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Future<AuthUser> signUpWithEmail(String email, String password) async {
    final key = email.trim().toLowerCase();
    if (!looksLikeEmail(key)) {
      throw const AuthException(
        AuthException.invalidEmail,
        "That email doesn't look right",
      );
    }
    if (password.length < passwordMinLength) {
      throw const AuthException(
        AuthException.weakPassword,
        'Use at least $passwordMinLength characters',
      );
    }
    if (_accounts.containsKey(key)) {
      throw const AuthException(
        AuthException.emailInUse,
        'That email already has an account. Try logging in.',
      );
    }
    final user = AuthUser(
      uid: 'auth_${_nextId++}',
      method: SignInMethod.email,
      email: key,
    );
    _accounts[key] = _Account(user, password);
    _setCurrent(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      // Same message either way, so it doesn't reveal who has an account.
      throw const AuthException(
        AuthException.wrongCredentials,
        "That email and password don't match",
      );
    }
    _setCurrent(account.user);
    return account.user;
  }

  @override
  Future<AuthUser> signInWithGoogle() =>
      _social(SignInMethod.google, 'you@gmail.com');

  @override
  Future<AuthUser> signInWithApple() =>
      _social(SignInMethod.apple, 'you@privaterelay.appleid.com');

  /// Signing in again with the same provider returns the same account.
  Future<AuthUser> _social(SignInMethod method, String email) async {
    if (socialSignInCancelled) {
      throw const AuthException(AuthException.cancelled, 'Sign-in cancelled');
    }
    final key = '${method.name}:$email';
    final account = _accounts.putIfAbsent(
      key,
      () => _Account(
        AuthUser(uid: 'auth_${_nextId++}', method: method, email: email),
        null,
      ),
    );
    _setCurrent(account.user);
    return account.user;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (!looksLikeEmail(email)) {
      throw const AuthException(
        AuthException.invalidEmail,
        "That email doesn't look right",
      );
    }
  }

  @override
  Future<void> signOut() async => _setCurrent(null);

  @override
  Future<void> deleteAccount() async {
    final user = _current;
    if (user == null) return;
    _accounts.removeWhere((_, a) => a.user == user);
    _setCurrent(null);
  }

  void dispose() => _controller.close();
}

class _Account {
  _Account(this.user, this.password);

  final AuthUser user;

  /// Null for Google/Apple accounts.
  final String? password;
}
