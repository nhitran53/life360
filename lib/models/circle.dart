import 'stat_metric.dart';

/// A label and default tone for a circle, not a separate system.
enum CircleType { couple, family, friends, team }

/// The most characters a reward may have.
const maxRewardLength = 80;

/// A named group of people who share stats with each other.
///
/// Holds only ids and a label, never any health data. [ownerId] is always in
/// [memberIds].
class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerId,
    required this.memberIds,
    required this.inviteCode,
    this.rewardText,
  }) : assert(rewardText == null || rewardText.length <= maxRewardLength);

  final String id;
  final String name;
  final CircleType type;
  final String ownerId;
  final List<String> memberIds;

  /// What someone types to join. Not secret enough to protect anything; the
  /// real invite flow will show what the circle can see first.
  final String inviteCode;

  /// What the weekly winner gets, e.g. "Winner picks the restaurant".
  final String? rewardText;

  bool hasMember(String userId) => memberIds.contains(userId);

  Circle copyWith({
    String? name,
    List<String>? memberIds,
    String? rewardText,
    bool clearReward = false,
  }) => Circle(
    id: id,
    name: name ?? this.name,
    type: type,
    ownerId: ownerId,
    memberIds: memberIds ?? this.memberIds,
    inviteCode: inviteCode,
    rewardText: clearReward ? null : rewardText ?? this.rewardText,
  );

  factory Circle.fromJson(Map<String, dynamic> json) => Circle(
    id: json['id'] as String,
    name: json['name'] as String,
    type: CircleType.values.byName(json['type'] as String),
    ownerId: json['ownerId'] as String,
    memberIds: List<String>.from(json['memberIds'] as List),
    inviteCode: json['inviteCode'] as String,
    rewardText: json['rewardText'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'ownerId': ownerId,
    'memberIds': memberIds,
    'inviteCode': inviteCode,
    'rewardText': rewardText,
  };
}

/// The metrics a reward may be decided on. Sleep, screen time and calories
/// are deliberately left out: nobody wins or loses on body-related numbers.
enum RewardMetric {
  steps(StatMetric.steps),
  workout(StatMetric.workout);

  const RewardMetric(this.stat);

  final StatMetric stat;
}

/// A reward for one circle and one week, and who won it once the week ended.
class CircleReward {
  const CircleReward({
    required this.circleId,
    required this.text,
    required this.metric,
    required this.weekStart,
    this.winnerIds = const [],
  }) : assert(text.length <= maxRewardLength);

  final String circleId;
  final String text;
  final RewardMetric metric;
  final DateTime weekStart;

  /// Empty until the week is over. Several ids means a tie.
  final List<String> winnerIds;

  CircleReward withWinners(List<String> ids) => CircleReward(
    circleId: circleId,
    text: text,
    metric: metric,
    weekStart: weekStart,
    winnerIds: ids,
  );

  factory CircleReward.fromJson(Map<String, dynamic> json) => CircleReward(
    circleId: json['circleId'] as String,
    text: json['text'] as String,
    metric: RewardMetric.values.byName(json['metric'] as String),
    weekStart: DateTime.parse(json['weekStart'] as String),
    winnerIds: List<String>.from(json['winnerIds'] as List),
  );

  Map<String, dynamic> toJson() => {
    'circleId': circleId,
    'text': text,
    'metric': metric.name,
    'weekStart': weekStart.toIso8601String(),
    'winnerIds': winnerIds,
  };
}
