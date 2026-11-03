import '../models/models.dart';

/// Accounts and friend relationships. Will be backed by Firebase later.
abstract interface class FriendsRepository {
  Future<UserProfile> currentUser();

  /// Accepted friends of the current user, sorted by display name.
  Future<List<UserProfile>> friends();

  /// Pending requests other people sent to the current user.
  Future<List<Friendship>> incomingRequests();

  /// Looks up a user by friend code (case-insensitive). Null if none.
  Future<UserProfile?> findByFriendCode(String code);

  /// Looks up any known user by id. Null if none.
  Future<UserProfile?> userById(String userId);

  /// Sends a request from the current user to [userId].
  ///
  /// Throws [FriendRequestException] when adding yourself, or when a pending
  /// or accepted friendship already exists.
  Future<Friendship> sendRequest(String userId);

  /// Accepts or declines an incoming request.
  Future<void> respondToRequest(String friendshipId, {required bool accept});
}

class FriendRequestException implements Exception {
  const FriendRequestException(this.message);
  final String message;

  @override
  String toString() => 'FriendRequestException: $message';
}
