import '../models/models.dart';
import 'friends_repository.dart';
import 'mock_data.dart';

/// In-memory [FriendsRepository] seeded with [mockAllUsers].
class MockFriendsRepository implements FriendsRepository {
  MockFriendsRepository({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    final now = _clock();
    for (final f in mockFriends) {
      _friendships.add(Friendship(
        id: 'f_${f.id}',
        requesterId: mockMe.id,
        addresseeId: f.id,
        status: FriendshipStatus.accepted,
        createdAt: now.subtract(const Duration(days: 30)),
      ));
    }
    _friendships.add(Friendship(
      id: 'f_${mockRequester.id}',
      requesterId: mockRequester.id,
      addresseeId: mockMe.id,
      status: FriendshipStatus.pending,
      createdAt: now.subtract(const Duration(hours: 5)),
    ));
  }

  final DateTime Function() _clock;
  final _friendships = <Friendship>[];
  var _nextId = 0;

  String get _me => mockMe.id;

  @override
  Future<UserProfile> currentUser() async => mockMe;

  @override
  Future<List<UserProfile>> friends() async {
    final ids = _friendships
        .where((f) => f.status == FriendshipStatus.accepted && f.involves(_me))
        .map((f) => f.otherUserId(_me))
        .toSet();
    return mockAllUsers.where((u) => ids.contains(u.id)).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<List<Friendship>> incomingRequests() async => _friendships
      .where((f) => f.status == FriendshipStatus.pending && f.addresseeId == _me)
      .toList();

  @override
  Future<List<Friendship>> outgoingRequests() async => _friendships
      .where((f) => f.status == FriendshipStatus.pending && f.requesterId == _me)
      .toList();

  @override
  Future<List<UserProfile>> searchUsers(String query) async {
    var q = query.trim().toLowerCase();
    if (q.startsWith('@')) q = q.substring(1);
    if (q.length < 2) return const [];
    return mockAllUsers
        .where((u) =>
            u.id != _me &&
            (u.username.toLowerCase().contains(q) ||
                u.displayName.toLowerCase().contains(q)))
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<UserProfile?> findByFriendCode(String code) async {
    final wanted = code.trim().toUpperCase();
    for (final u in mockAllUsers) {
      if (u.friendCode == wanted) return u;
    }
    return null;
  }

  /// Mock users have no emails.
  @override
  Future<UserProfile?> findByEmail(String email) async => null;

  @override
  Future<List<UserProfile>> suggestions({int limit = 8}) async {
    final taken = {
      _me,
      for (final f in _friendships)
        if (f.involves(_me) && f.status != FriendshipStatus.declined)
          f.otherUserId(_me),
    };
    return mockAllUsers
        .where((u) => !taken.contains(u.id))
        .take(limit)
        .toList();
  }

  @override
  Future<UserProfile?> userById(String userId) async {
    for (final u in mockAllUsers) {
      if (u.id == userId) return u;
    }
    return null;
  }

  @override
  Future<Friendship> sendRequest(String userId) async {
    if (userId == _me) {
      throw const FriendRequestException("You can't add yourself 😅");
    }
    if (await userById(userId) == null) {
      throw const FriendRequestException('User not found');
    }
    final existing = _friendships.where((f) =>
        f.involves(_me) &&
        f.involves(userId) &&
        f.status != FriendshipStatus.declined);
    if (existing.isNotEmpty) {
      throw FriendRequestException(
          existing.first.status == FriendshipStatus.accepted
              ? "You're already friends"
              : 'A request is already pending');
    }
    final request = Friendship(
      id: 'f_new_${_nextId++}',
      requesterId: _me,
      addresseeId: userId,
      status: FriendshipStatus.pending,
      createdAt: _clock(),
    );
    _friendships.add(request);
    return request;
  }

  @override
  Future<void> respondToRequest(String friendshipId,
      {required bool accept}) async {
    final i = _friendships.indexWhere((f) =>
        f.id == friendshipId &&
        f.addresseeId == _me &&
        f.status == FriendshipStatus.pending);
    if (i == -1) {
      throw const FriendRequestException('Request not found');
    }
    _friendships[i] = _friendships[i].copyWith(
      status: accept ? FriendshipStatus.accepted : FriendshipStatus.declined,
    );
  }

  @override
  Future<void> cancelRequest(String friendshipId) async {
    final removed = _removeWhere((f) =>
        f.id == friendshipId &&
        f.requesterId == _me &&
        f.status == FriendshipStatus.pending);
    if (!removed) throw const FriendRequestException('Request not found');
  }

  @override
  Future<void> removeFriend(String userId) async {
    final removed = _removeWhere((f) =>
        f.involves(_me) &&
        f.involves(userId) &&
        f.status == FriendshipStatus.accepted);
    if (!removed) throw const FriendRequestException("You're not friends");
  }

  bool _removeWhere(bool Function(Friendship) test) {
    final before = _friendships.length;
    _friendships.removeWhere(test);
    return _friendships.length < before;
  }
}
