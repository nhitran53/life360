import '../models/circle.dart';

/// How a [CircleType] reads in the UI.
extension CircleTypeLabel on CircleType {
  String get label => switch (this) {
    CircleType.couple => 'Couple',
    CircleType.family => 'Family',
    CircleType.friends => 'Friends',
    CircleType.team => 'Team',
  };

  String get emoji => switch (this) {
    CircleType.couple => '💞',
    CircleType.family => '🏡',
    CircleType.friends => '🎉',
    CircleType.team => '🏅',
  };
}

/// "1 member" / "3 members".
String memberCountLabel(int count) =>
    count == 1 ? '1 member' : '$count members';
