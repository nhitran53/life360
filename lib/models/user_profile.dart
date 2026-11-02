/// A person in the app: the current user or one of their friends.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.username,
    required this.avatarEmoji,
    required this.friendCode,
  });

  final String id;
  final String displayName;
  final String username;

  /// Placeholder avatar until we have real profile pictures / a mascot.
  final String avatarEmoji;

  /// Short code other people type to add this user as a friend.
  final String friendCode;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        username: json['username'] as String,
        avatarEmoji: json['avatarEmoji'] as String,
        friendCode: json['friendCode'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'username': username,
        'avatarEmoji': avatarEmoji,
        'friendCode': friendCode,
      };

  @override
  bool operator ==(Object other) => other is UserProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserProfile($id, @$username)';
}
