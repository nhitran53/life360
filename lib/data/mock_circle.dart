import 'package:flutter/material.dart';

import '../theme/circle_colors.dart';

/// A member of the user's circle, with the live stats the Circle screens show.
///
/// Placeholder data matching the Figma mock until the repositories expose
/// heart rate and activity.
class CircleMember {
  const CircleMember({
    required this.id,
    required this.name,
    required this.initial,
    required this.color,
    required this.status,
    required this.bpm,
    required this.activity,
    required this.steps,
    required this.activeMinutes,
    required this.sleep,
    required this.restingBpm,
    required this.weekSteps,
    required this.shares,
    required this.nudgeHint,
    required this.objectPronoun,
    this.idle = false,
    this.idleFor,
  });

  final String id;
  final String name;
  final String initial;
  final Color color;

  /// Short line under the name in the member list.
  final String status;

  final int bpm;

  /// What they're doing right now, e.g. "walking".
  final String activity;

  final int steps;
  final int activeMinutes;

  /// Last night's sleep, already formatted ("7h 12m").
  final String sleep;

  final int restingBpm;

  /// Steps for each day of this week, Monday first; the last entry is today.
  final List<int> weekSteps;

  /// Which stats they share, e.g. "heart rate, steps & sleep".
  final String shares;

  /// Context shown when they're picked as a nudge recipient.
  final String nudgeHint;

  /// Used in "Cheer her on".
  final String objectPronoun;

  /// Hasn't moved in a while; shows a Nudge button instead of heart rate.
  final bool idle;

  /// How long they've been idle, e.g. "3h" (shown as "idle 3h" on the map).
  final String? idleFor;

  /// High enough to highlight in red on the pulse map.
  bool get highHeartRate => bpm >= 120;
}

const circleStepGoal = 10000;
const circleActiveGoal = 60;

const circleMom = CircleMember(
  id: 'mom',
  name: 'Mom',
  initial: 'M',
  color: CircleColors.avatarMom,
  status: 'Walking · now',
  bpm: 78,
  activity: 'walking',
  steps: 8240,
  activeMinutes: 42,
  sleep: '7h 12m',
  restingBpm: 66,
  weekSteps: [6303, 8898, 5005, 10381, 7415, 9269, 6859],
  shares: 'heart rate, steps & sleep',
  nudgeHint: 'Mom is out walking · 8,240 steps today',
  objectPronoun: 'her',
);

const circleDad = CircleMember(
  id: 'dad',
  name: 'Dad',
  initial: 'D',
  color: CircleColors.avatarDad,
  status: '3,105 steps · idle 3h',
  bpm: 64,
  activity: 'resting',
  steps: 3105,
  activeMinutes: 8,
  sleep: '6h 40m',
  restingBpm: 62,
  weekSteps: [5210, 4870, 6120, 3990, 5530, 4410, 3105],
  shares: 'heart rate & steps',
  nudgeHint: 'Dad has been idle for 3 hours · 3,105 steps today',
  objectPronoun: 'him',
  idle: true,
  idleFor: '3h',
);

const circleBao = CircleMember(
  id: 'bao',
  name: 'Bao',
  initial: 'B',
  color: CircleColors.avatarBao,
  status: 'Running · 24 min',
  bpm: 132,
  activity: 'running',
  steps: 11980,
  activeMinutes: 58,
  sleep: '8h 05m',
  restingBpm: 58,
  weekSteps: [9840, 12110, 8730, 13020, 10450, 11290, 11980],
  shares: 'heart rate, steps & sleep',
  nudgeHint: 'Bao is running · 11,980 steps today',
  objectPronoun: 'them',
);

const circleLinh = CircleMember(
  id: 'linh',
  name: 'Linh',
  initial: 'L',
  color: CircleColors.avatarLinh,
  status: 'Studying · 1h',
  bpm: 70,
  activity: 'sitting',
  steps: 4560,
  activeMinutes: 21,
  sleep: '7h 30m',
  restingBpm: 64,
  weekSteps: [5620, 7010, 4880, 6340, 5970, 3820, 4560],
  shares: 'heart rate & steps',
  nudgeHint: 'Linh has been sitting for 1 hour · 4,560 steps today',
  objectPronoun: 'them',
);

/// Shown as rows on the Circle home, in this order.
const circleListMembers = [circleMom, circleDad, circleBao];

/// Everyone you can nudge, in chip order.
const circleNudgeMembers = [circleDad, circleMom, circleBao, circleLinh];

const circleQuickNotes = [
  'Time for a 10-minute walk?',
  'You’re 2,000 steps from your goal!',
  'Join me for a walk at 6 tonight?',
  'Stand up, stretch and drink some water',
];

/// Your own live stats, shown as "You" in the middle of the pulse map.
const circleYouBpm = 71;
const circleYouSteps = 10527;

// ---------------------------------------------------------------------------
// FAMILIES — the circles you belong to (switch with the header button)
// ---------------------------------------------------------------------------

/// A family (or friend group) you share stats with.
class CircleFamily {
  const CircleFamily({
    required this.id,
    required this.name,
    this.mapMembers = const [],
    this.listMembers = const [],
  });

  final String id;
  final String name;

  /// Placed around "You" on the pulse map, in order (the map has 4 spots).
  final List<CircleMember> mapMembers;

  /// Shown as rows under "Together today".
  final List<CircleMember> listMembers;

  /// Everyone in the family except you.
  List<CircleMember> get members => {...mapMembers, ...listMembers}.toList();

  /// Including you.
  int get memberCount => members.length + 1;

  int get stepsToday =>
      members.fold(circleYouSteps, (sum, member) => sum + member.steps);

  /// Everyone's daily step goal added together.
  int get stepsGoal => circleStepGoal * memberCount;
}

const circleTranFamily = CircleFamily(
  id: 'tran',
  name: 'Tran family',
  mapMembers: [circleMom, circleDad, circleBao, circleLinh],
  listMembers: circleListMembers,
);

/// The families you start with. New ones are added from the Circle header.
const circleFamilies = [circleTranFamily];