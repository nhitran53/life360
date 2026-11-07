import '../models/models.dart';

/// Accounts and friend relationships. Will be backed by Firebase later.
abstract interface class FriendsRepository {
  Future<UserProfile> currentUser();

  /// Accepted friends of the current user, sorted by display name.
  Future<List<UserProfile>> friends();

  /// Pending requests other people sent to the current user.
  Future<List<Friendship>> incomingRequests();

  /// Pending requests the current user sent and nobody has answered yet.
  Future<List<Friendship>> outgoingRequests();

  /// Looks up a user by friend code (case-insensitive). Null if none.
  Future<UserProfile?> findByFriendCode(String code);

  /// People whose username or display name contains [query]
  /// (case-insensitive, a leading "@" is ignored), never the current user.
  /// Empty for queries shorter than 2 characters.
  Future<List<UserProfile>> searchUsers(String query);

  /// Looks up any known user by id. Null if none.
  Future<UserProfile?> userById(String userId);

  /// Sends a request from the current user to [userId].
  ///
  /// Throws [FriendRequestException] when adding yourself, or when a pending
  /// or accepted friendship already exists.
  Future<Friendship> sendRequest(String userId);

  /// Accepts or declines an incoming request.
  Future<void> respondToRequest(String friendshipId, {required bool accept});

  /// Withdraws a request the current user sent that is still pending.
  Future<void> cancelRequest(String friendshipId);

  /// Ends an accepted friendship. Either person can do it, and the other
  /// person isn't told.
  Future<void> removeFriend(String userId);
}

class FriendRequestException implements Exception {
  const FriendRequestException(this.message);
  final String message;

  @override
  String toString() => 'FriendRequestException: $message';
}
