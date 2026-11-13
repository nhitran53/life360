import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'friends_repository.dart';

/// Id of the one friendship document for a pair: the two uids sorted and
/// joined with "_" (Firebase uids never contain "_"). Must match
/// `isPairId` in firestore.rules.
String friendshipId(String a, String b) =>
    a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

/// [FriendsRepository] backed by Firestore, for the signed-in [me].
///
/// `friendships/{pair id}` holds `requesterId`, `addresseeId`,
/// `users: [requester, addressee]`, `status` ("pending" or "accepted") and
/// `createdAt`. Declining, cancelling and unfriending delete the document,
/// so a declined person can ask again later.
class FirestoreFriendsRepository implements FriendsRepository {
  FirestoreFriendsRepository(this._db, {required this._me});

  final FirebaseFirestore _db;
  final UserProfile _me;

  /// Most results a username search returns.
  static const searchLimit = 20;

  CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection('friendships');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  static UserProfile _profile(DocumentSnapshot<Map<String, dynamic>> snap) =>
      UserProfile.fromJson({...snap.data()!, 'id': snap.id});

  static Friendship _friendship(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    // createdAt is null in the local copy until the server sets it.
    final created = data['createdAt'];
    return Friendship(
      id: snap.id,
      requesterId: data['requesterId'] as String,
      addresseeId: data['addresseeId'] as String,
      status: FriendshipStatus.values.byName(data['status'] as String),
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
    );
  }

  /// Every friendship and request you're part of. One query covers them
  /// all (and is the only kind of list query the rules allow).
  Future<List<Friendship>> _mine() async {
    final snap = await _friendships.where('users', arrayContains: _me.id).get();
    return snap.docs.map(_friendship).toList();
  }

  @override
  Future<UserProfile> currentUser() async => _me;

  @override
  Future<List<UserProfile>> friends() async {
    final ids = [
      for (final f in await _mine())
        if (f.status == FriendshipStatus.accepted) f.otherUserId(_me.id),
    ];
    final profiles = await Future.wait(ids.map(userById));
    return profiles.whereType<UserProfile>().toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<List<Friendship>> incomingRequests() async => [
    for (final f in await _mine())
      if (f.status == FriendshipStatus.pending && f.addresseeId == _me.id) f,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Friendship>> outgoingRequests() async => [
    for (final f in await _mine())
      if (f.status == FriendshipStatus.pending && f.requesterId == _me.id) f,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<UserProfile?> findByFriendCode(String code) async {
    final wanted = code.trim().toUpperCase();
    if (wanted.length != friendCodeLength) return null;
    final claim = await _db.collection('friendCodes').doc(wanted).get();
    final uid = claim.data()?['uid'];
    return uid is String ? userById(uid) : null;
  }

  /// Usernames that start with [query] (Firestore can't search inside a
  /// string, so this is a prefix search on @username only).
  @override
  Future<List<UserProfile>> searchUsers(String query) async {
    final q = normalizeUsername(query);
    if (q.length < 2) return const [];
    final snap = await _users
        .where('username', isGreaterThanOrEqualTo: q)
        .where('username', isLessThan: '$q')
        .limit(searchLimit + 1) // +1 in case one of them is you
        .get();
    return snap.docs
        .where((d) => d.id != _me.id)
        .map(_profile)
        .take(searchLimit)
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<UserProfile?> findByEmail(String email) async {
    final wanted = normalizeEmail(email);
    if (!looksLikeEmail(wanted)) return null;
    final claim = await _db.collection('emails').doc(wanted).get();
    final uid = claim.data()?['uid'];
    return uid is String ? userById(uid) : null;
  }

  /// How many of the newest accounts [suggestions] looks through.
  static const suggestionPool = 30;

  @override
  Future<List<UserProfile>> suggestions({int limit = 8}) async {
    final taken = {
      _me.id,
      for (final f in await _mine()) f.otherUserId(_me.id),
    };
    final snap = await _users
        .orderBy('createdAt', descending: true)
        .limit(suggestionPool)
        .get();
    return snap.docs
        .where((d) => !taken.contains(d.id))
        .map(_profile)
        .take(limit)
        .toList();
  }

  @override
  Future<UserProfile?> userById(String userId) async {
    if (userId == _me.id) return _me;
    final snap = await _users.doc(userId).get();
    return snap.exists ? _profile(snap) : null;
  }

  @override
  Future<Friendship> sendRequest(String userId) async {
    if (userId == _me.id) {
      throw const FriendRequestException("You can't add yourself 😅");
    }
    if (await userById(userId) == null) {
      throw const FriendRequestException('User not found');
    }
    final ref = _friendships.doc(friendshipId(_me.id, userId));
    await _db.runTransaction<void>((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) {
        final f = _friendship(existing);
        throw FriendRequestException(switch (f) {
          _ when f.status == FriendshipStatus.accepted =>
            "You're already friends",
          _ when f.requesterId == userId =>
            'They already sent you a request. Check your requests!',
          _ => 'A request is already pending',
        });
      }
      tx.set(ref, {
        'requesterId': _me.id,
        'addresseeId': userId,
        'users': [_me.id, userId],
        'status': FriendshipStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return Friendship(
      id: ref.id,
      requesterId: _me.id,
      addresseeId: userId,
      status: FriendshipStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  /// Loads [friendshipId] if it's a pending request matching [test].
  Future<DocumentReference<Map<String, dynamic>>> _pending(
    String friendshipId,
    bool Function(Friendship) test,
  ) async {
    final ref = _friendships.doc(friendshipId);
    final snap = await ref.get();
    if (!snap.exists) throw const FriendRequestException('Request not found');
    final f = _friendship(snap);
    if (f.status != FriendshipStatus.pending || !test(f)) {
      throw const FriendRequestException('Request not found');
    }
    return ref;
  }

  @override
  Future<void> respondToRequest(
    String friendshipId, {
    required bool accept,
  }) async {
    final ref = await _pending(friendshipId, (f) => f.addresseeId == _me.id);
    if (accept) {
      await ref.update({
        'status': FriendshipStatus.accepted.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  @override
  Future<void> cancelRequest(String friendshipId) async {
    final ref = await _pending(friendshipId, (f) => f.requesterId == _me.id);
    await ref.delete();
  }

  @override
  Future<void> removeFriend(String userId) async {
    final ref = _friendships.doc(friendshipId(_me.id, userId));
    final snap = await ref.get();
    if (!snap.exists || _friendship(snap).status != FriendshipStatus.accepted) {
      throw const FriendRequestException("You're not friends");
    }
    await ref.delete();
  }
}
