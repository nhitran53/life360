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
  Future<UserProfile?> findByFriendCode(String code) async {
    final wanted = code.trim().toUpperCase();
    for (final u in mockAllUsers) {
      if (u.friendCode == wanted) return u;
    }
    return null;
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
}
