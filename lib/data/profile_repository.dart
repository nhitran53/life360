import '../models/models.dart';

/// Each account's public profile (name, @username, avatar, friend code) and
/// private daily goals. Firestore will implement this.
abstract interface class ProfileRepository {
  /// Null until the user finishes onboarding.
  Future<UserProfile?> profileFor(String uid);

  /// The user's daily goals, or the defaults if they never set any.
  Future<DailyGoals> goalsFor(String uid);

  /// [username] must already be normalized (see [normalizeUsername]).
  Future<bool> isUsernameAvailable(String username);

  /// Saves a new profile with a fresh unique friend code.
  ///
  /// Throws [ProfileException] if the username was taken in the meantime.
  Future<UserProfile> createProfile({
    required String uid,
    required String displayName,
    required String username,
    required String avatarEmoji,
    DailyGoals goals = const DailyGoals(),
  });

  Future<void> updateGoals(String uid, DailyGoals goals);

  /// Saves the email [uid] signed in with, so friends can find them by it.
  /// Safe to call again with the same email.
  Future<void> saveEmail(String uid, String email);

  /// The saved email for [uid], or null if none was saved yet. Only the
  /// owner can read it.
  Future<String?> emailFor(String uid);

  /// Removes the profile, goals and saved email, and frees the username,
  /// friend code and email lookup.
  Future<void> deleteProfile(String uid);
}

class ProfileException implements Exception {
  const ProfileException(this.message);
  final String message;

  @override
  String toString() => 'ProfileException: $message';
}
