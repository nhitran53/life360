enum FriendshipStatus { pending, accepted, declined }

/// A friend request between two users, and its outcome.
class Friendship {
  const Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;

  bool involves(String userId) =>
      requesterId == userId || addresseeId == userId;

  /// The other person in this friendship, from [userId]'s point of view.
  String otherUserId(String userId) {
    if (userId == requesterId) return addresseeId;
    if (userId == addresseeId) return requesterId;
    throw ArgumentError.value(userId, 'userId', 'not part of friendship $id');
  }

  Friendship copyWith({FriendshipStatus? status}) => Friendship(
        id: id,
        requesterId: requesterId,
        addresseeId: addresseeId,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  factory Friendship.fromJson(Map<String, dynamic> json) => Friendship(
        id: json['id'] as String,
        requesterId: json['requesterId'] as String,
        addresseeId: json['addresseeId'] as String,
        status: FriendshipStatus.values.byName(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'requesterId': requesterId,
        'addresseeId': addresseeId,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };
}
