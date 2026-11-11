import 'mock_circle.dart';

// ---------------------------------------------------------------------------
// NOTIFICATIONS — goals you (or your family) hit, and nudges sent to you.
// Mock data until notifications come from the backend.
// ---------------------------------------------------------------------------

enum CircleNotificationKind { goal, nudge }

class CircleNotification {
  const CircleNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.timeAgo,
    this.today = true,
    this.unread = false,
    this.from,
    this.emoji = '🎯',
  });

  final String id;
  final CircleNotificationKind kind;
  final String title;
  final String body;

  /// Short label like "5m", "1h", "Yesterday".
  final String timeAgo;

  /// Shown under "Today" when true, "Earlier" otherwise.
  final bool today;

  /// New since you last opened notifications.
  final bool unread;

  /// Who it's about or who sent it (null = you or the whole family).
  final CircleMember? from;

  /// Shown when there's no [from] avatar.
  final String emoji;

  bool get isNudge => kind == CircleNotificationKind.nudge;
}

const mockNotifications = [
  CircleNotification(
    id: 'n1',
    kind: CircleNotificationKind.nudge,
    title: 'Mom nudged you',
    body: '“Time for a 10-minute walk?” 🚶',
    timeAgo: '5m',
    unread: true,
    from: circleMom,
  ),
  CircleNotification(
    id: 'n2',
    kind: CircleNotificationKind.goal,
    title: 'You hit your step goal',
    body: '10,527 steps today. Nice work!',
    timeAgo: '32m',
    unread: true,
    emoji: '🎯',
  ),
  CircleNotification(
    id: 'n3',
    kind: CircleNotificationKind.goal,
    title: 'Bao crushed 10,000 steps 🔥',
    body: '11,980 steps and counting',
    timeAgo: '1h',
    unread: true,
    from: circleBao,
  ),
  CircleNotification(
    id: 'n4',
    kind: CircleNotificationKind.nudge,
    title: 'Linh nudged you',
    body: '“Drink some water!” 💧',
    timeAgo: '2h',
    from: circleLinh,
  ),
  CircleNotification(
    id: 'n5',
    kind: CircleNotificationKind.goal,
    title: 'Tran family is 77% to today’s goal',
    body: 'Only 11,588 steps to go together',
    timeAgo: '3h',
    emoji: '👪',
  ),
  CircleNotification(
    id: 'n6',
    kind: CircleNotificationKind.goal,
    title: 'You beat your sleep goal',
    body: '7h 42m last night 😴',
    timeAgo: 'Yesterday',
    today: false,
    emoji: '🌙',
  ),
  CircleNotification(
    id: 'n7',
    kind: CircleNotificationKind.nudge,
    title: 'Dad nudged you',
    body: '“Race you to 8,000 steps tomorrow?”',
    timeAgo: 'Yesterday',
    today: false,
    from: circleDad,
  ),
  CircleNotification(
    id: 'n8',
    kind: CircleNotificationKind.goal,
    title: '4-day step streak',
    body: 'You’ve hit your step goal 4 days in a row 🏆',
    timeAgo: 'Mon',
    today: false,
    emoji: '🏆',
  ),
];