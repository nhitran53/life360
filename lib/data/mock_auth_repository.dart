import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/models.dart';
import 'auth_repository.dart';
import 'local_account_store.dart';

/// Local accounts, so the sign-in flow works where Firebase isn't set up.
///
/// By default everything is forgotten when the app restarts. Use
/// [MockAuthRepository.persistent] to keep accounts and the signed-in user
/// on the device instead (passwords are stored only as salted hashes).
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.socialSignInCancelled = false}) : _store = null;

  MockAuthRepository._persistent(LocalAccountStore store)
    : _store = store,
      socialSignInCancelled = false;

  /// Loads the accounts saved in [store] and signs back in whoever was
  /// signed in when the app closed.
  static Future<MockAuthRepository> persistent(LocalAccountStore store) async {
    final repo = MockAuthRepository._persistent(store);
    await repo._restore();
    return repo;
  }

  static const _storeKey = 'auth';

  final LocalAccountStore? _store;

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
    unawaited(_persist());
  }

  Future<void> _restore() async {
    final data = await _store?.load(_storeKey);
    if (data == null) return;
    _nextId = data['nextId'] as int? ?? 0;
    final accounts = (data['accounts'] as Map<String, dynamic>? ?? {});
    for (final MapEntry(:key, :value) in accounts.entries) {
      _accounts[key] = _Account.fromJson(value as Map<String, dynamic>);
    }
    final currentUid = data['currentUid'] as String?;
    for (final account in _accounts.values) {
      if (account.user.uid == currentUid) _current = account.user;
    }
  }

  Future<void> _persist() async {
    final store = _store;
    if (store == null) return;
    await store.save(_storeKey, {
      'nextId': _nextId,
      'currentUid': _current?.uid,
      'accounts': {
        for (final MapEntry(:key, :value) in _accounts.entries)
          key: value.toJson(),
      },
    });
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
    _accounts[key] = _Account.withPassword(user, password);
    _setCurrent(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || !account.checkPassword(password)) {
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
  _Account(this.user, [this._salt, this._passwordHash]);

  factory _Account.withPassword(AuthUser user, String password) {
    final random = Random.secure();
    final salt = base64Encode(List.generate(16, (_) => random.nextInt(256)));
    return _Account(user, salt, _hash(salt, password));
  }

  factory _Account.fromJson(Map<String, dynamic> json) => _Account(
    AuthUser(
      uid: json['uid'] as String,
      method: SignInMethod.values.byName(json['method'] as String),
      email: json['email'] as String?,
    ),
    json['salt'] as String?,
    json['passwordHash'] as String?,
  );

  final AuthUser user;

  /// Both null for Google/Apple accounts.
  final String? _salt;
  final String? _passwordHash;

  bool checkPassword(String password) {
    final salt = _salt;
    return salt != null && _passwordHash == _hash(salt, password);
  }

  static String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  Map<String, dynamic> toJson() => {
    'uid': user.uid,
    'method': user.method.name,
    'email': user.email,
    'salt': _salt,
    'passwordHash': _passwordHash,
  };
}
