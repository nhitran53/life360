import 'dart:math';

/// How someone signed in.
enum SignInMethod {
  email(label: 'Email'),
  google(label: 'Google'),
  apple(label: 'Apple');

  const SignInMethod({required this.label});

  final String label;
}

/// A signed-in account. This is only who you are to the auth system: your
/// name, username and avatar live in your [UserProfile].
class AuthUser {
  const AuthUser({required this.uid, required this.method, this.email});

  final String uid;
  final SignInMethod method;

  /// Can be null, e.g. with Apple's "Hide my email".
  final String? email;

  @override
  bool operator ==(Object other) => other is AuthUser && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'AuthUser($uid, ${method.name})';
}

/// Lowercase letters, digits, "_" and ".", starting with a letter.
final _usernamePattern = RegExp(r'^[a-z][a-z0-9_.]*$');
final _startsWithLetter = RegExp('^[a-z]');
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

const usernameMinLength = 3;
const usernameMaxLength = 20;

/// " @Alex.R " → "alex.r". Usernames are stored like this.
String normalizeUsername(String input) {
  var name = input.trim().toLowerCase();
  if (name.startsWith('@')) name = name.substring(1);
  return name;
}

/// Why [username] (already normalized) can't be used, or null if it can.
String? usernameProblem(String username) {
  if (username.isEmpty) return 'Pick a username';
  if (username.length < usernameMinLength) {
    return 'At least $usernameMinLength characters';
  }
  if (username.length > usernameMaxLength) {
    return 'At most $usernameMaxLength characters';
  }
  if (!_startsWithLetter.hasMatch(username)) return 'Start with a letter';
  if (!_usernamePattern.hasMatch(username)) {
    return 'Only letters, numbers, _ and .';
  }
  if (username.contains('..') || username.endsWith('.')) {
    return "Dots can't be doubled or at the end";
  }
  return null;
}

/// Why [displayName] can't be used, or null if it can.
String? displayNameProblem(String displayName) {
  final name = displayName.trim();
  if (name.isEmpty) return "What's your name?";
  if (name.length > 30) return 'At most 30 characters';
  return null;
}

/// " Alex@Mail.com " → "alex@mail.com". Emails are stored and looked up
/// like this.
String normalizeEmail(String email) => email.trim().toLowerCase();

/// Very loose check: something@something.something. The auth backend does
/// the real validation.
bool looksLikeEmail(String email) =>
    _emailPattern.hasMatch(email.trim());

const passwordMinLength = 8;

/// Letters and digits that are hard to mix up (no 0/O, 1/I/L).
const _friendCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const friendCodeLength = 6;

/// A random friend code, e.g. "K7QM2X". Callers check it's not taken.
String generateFriendCode([Random? random]) {
  final r = random ?? Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < friendCodeLength; i++)
      _friendCodeAlphabet.codeUnitAt(r.nextInt(_friendCodeAlphabet.length)),
  ]);
}

/// Avatars to choose from during onboarding, until we have the mascot.
const avatarChoices = [
  '😎', '🦊', '🐼', '🐸', '🦁', '🐯', //
  '🐨', '🐙', '🦄', '🐢', '🐝', '🌟',
];
