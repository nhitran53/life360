import '../models/models.dart';

/// Sign-up, sign-in and sign-out. Firebase Auth will implement this; until
/// then [MockAuthRepository] keeps accounts in memory.
abstract interface class AuthRepository {
  /// Who's signed in right now, or null.
  AuthUser? get currentUser;

  /// Emits the signed-in user (or null) whenever it changes.
  Stream<AuthUser?> authStateChanges();

  /// Throws [AuthException] if the email is taken or the password is weak.
  Future<AuthUser> signUpWithEmail(String email, String password);

  /// Throws [AuthException] if the email or password is wrong.
  Future<AuthUser> signInWithEmail(String email, String password);

  /// Opens the Google sign-in sheet. Throws [AuthException] with
  /// [AuthException.cancelled] if the user backs out.
  Future<AuthUser> signInWithGoogle();

  /// Sign in with Apple. Required by the App Store whenever another social
  /// sign-in (Google) is offered on iOS.
  Future<AuthUser> signInWithApple();

  /// Emails a reset link. Succeeds even if no account uses [email], so
  /// nobody can use it to find out who has an account.
  Future<void> sendPasswordReset(String email);

  Future<void> signOut();

  /// Deletes the signed-in account from the auth system. Delete the user's
  /// data first (see [AccountSession.deleteAccount]).
  ///
  /// May throw [AuthException] with [AuthException.requiresRecentLogin].
  Future<void> deleteAccount();
}

class AuthException implements Exception {
  const AuthException(this.code, this.message);

  /// The user closed the Google/Apple sheet. Not worth showing an error.
  static const cancelled = 'cancelled';

  /// The account was signed into too long ago to delete it safely.
  static const requiresRecentLogin = 'requires-recent-login';

  static const emailInUse = 'email-already-in-use';
  static const wrongCredentials = 'invalid-credential';
  static const weakPassword = 'weak-password';
  static const invalidEmail = 'invalid-email';

  final String code;

  /// Friendly text to show the user.
  final String message;

  bool get isCancelled => code == cancelled;

  @override
  String toString() => 'AuthException($code): $message';
}
