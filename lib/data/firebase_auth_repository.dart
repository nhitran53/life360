import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/models.dart';
import 'auth_repository.dart';

/// [AuthRepository] backed by Firebase Auth.
///
/// Google sign-in goes through the `google_sign_in` package (on Android it
/// reads the web client ID from google-services.json), then hands the ID
/// token to Firebase. Apple uses Firebase's own provider flow.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? fb.FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _google;
  Future<void>? _googleReady;

  /// Firebase asks for a fresh sign-in before deleting an account if the
  /// last one was more than about 5 minutes ago.
  static const _recentLoginWindow = Duration(minutes: 5);

  static AuthUser? _toUser(fb.User? user) {
    if (user == null) return null;
    final providers = user.providerData.map((p) => p.providerId).toSet();
    final method = providers.contains('google.com')
        ? SignInMethod.google
        : providers.contains('apple.com')
        ? SignInMethod.apple
        : SignInMethod.email;
    return AuthUser(uid: user.uid, method: method, email: user.email);
  }

  @override
  AuthUser? get currentUser => _toUser(_auth.currentUser);

  @override
  bool get signedInRecently {
    final last = _auth.currentUser?.metadata.lastSignInTime;
    return last != null && DateTime.now().difference(last) < _recentLoginWindow;
  }

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(_toUser);

  @override
  Future<AuthUser> signUpWithEmail(String email, String password) =>
      _guard(() async {
        final result = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return _toUser(result.user)!;
      });

  @override
  Future<AuthUser> signInWithEmail(String email, String password) =>
      _guard(() async {
        final result = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return _toUser(result.user)!;
      });

  @override
  Future<AuthUser> signInWithGoogle() => _guard(() async {
    await (_googleReady ??= _google.initialize());
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthException(AuthException.cancelled, 'Sign-in cancelled');
      }
      // Don't log account details, just the kind of failure.
      debugPrint('Google sign-in failed: ${e.code.name}');
      throw const AuthException(
        'google-failed',
        "Couldn't sign in with Google. Try again in a moment.",
      );
    }
    final idToken = account.authentication.idToken;
    final result = await _auth.signInWithCredential(
      fb.GoogleAuthProvider.credential(idToken: idToken),
    );
    return _toUser(result.user)!;
  });

  @override
  Future<AuthUser> signInWithApple() => _guard(() async {
    final provider = fb.AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final result = await _auth.signInWithProvider(provider);
    return _toUser(result.user)!;
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() async {
    // Also forget the Google account, so the picker shows next time.
    if (_googleReady != null) await _google.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() => _guard(() async {
    await _auth.currentUser?.delete();
    if (_googleReady != null) await _google.disconnect();
  });

  /// Turns Firebase errors into friendly [AuthException]s.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on fb.FirebaseAuthException catch (e) {
      throw _friendly(e);
    }
  }

  static AuthException _friendly(fb.FirebaseAuthException e) =>
      switch (e.code) {
        'email-already-in-use' => const AuthException(
          AuthException.emailInUse,
          'That email already has an account. Try logging in.',
        ),
        'invalid-email' => const AuthException(
          AuthException.invalidEmail,
          "That email doesn't look right",
        ),
        'weak-password' => const AuthException(
          AuthException.weakPassword,
          'Pick a stronger password (at least $passwordMinLength characters)',
        ),
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'INVALID_LOGIN_CREDENTIALS' => const AuthException(
          AuthException.wrongCredentials,
          "That email and password don't match",
        ),
        'requires-recent-login' => const AuthException(
          AuthException.requiresRecentLogin,
          'For safety, log out and back in, then try again.',
        ),
        'too-many-requests' => const AuthException(
          'too-many-requests',
          'Too many tries. Take a breather and try again soon.',
        ),
        'network-request-failed' => const AuthException(
          'network',
          "You're offline. Check your connection and try again.",
        ),
        'user-disabled' => const AuthException(
          'user-disabled',
          'This account has been turned off.',
        ),
        'web-context-canceled' || 'canceled' => const AuthException(
          AuthException.cancelled,
          'Sign-in cancelled',
        ),
        _ => AuthException(e.code, 'Something went wrong. Try again.'),
      };
}
