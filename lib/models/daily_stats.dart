import 'dates.dart';

/// One user's health stats for one calendar day.
///
/// Values are daily totals only, never raw samples, so this is the shape we
/// will sync to the backend later.
class DailyStats {
  DailyStats({
    required this.userId,
    required DateTime date,
    this.steps = 0,
    this.sleepMinutes = 0,
    this.workoutMinutes = 0,
    this.activeCalories = 0,
    this.screenTimeMinutes = 0,
  })  : date = dateOnly(date),
        assert(steps >= 0 &&
            sleepMinutes >= 0 &&
            workoutMinutes >= 0 &&
            activeCalories >= 0 &&
            screenTimeMinutes >= 0);

  final String userId;

  /// Local calendar day (time part is always midnight).
  final DateTime date;

  final int steps;
  final int sleepMinutes;
  final int workoutMinutes;
  final int activeCalories;
  final int screenTimeMinutes;

  DailyStats copyWith({
    int? steps,
    int? sleepMinutes,
    int? workoutMinutes,
    int? activeCalories,
    int? screenTimeMinutes,
  }) =>
      DailyStats(
        userId: userId,
        date: date,
        steps: steps ?? this.steps,
        sleepMinutes: sleepMinutes ?? this.sleepMinutes,
        workoutMinutes: workoutMinutes ?? this.workoutMinutes,
        activeCalories: activeCalories ?? this.activeCalories,
        screenTimeMinutes: screenTimeMinutes ?? this.screenTimeMinutes,
      );

  factory DailyStats.fromJson(Map<String, dynamic> json) => DailyStats(
        userId: json['userId'] as String,
        date: DateTime.parse(json['date'] as String),
        steps: json['steps'] as int? ?? 0,
        sleepMinutes: json['sleepMinutes'] as int? ?? 0,
        workoutMinutes: json['workoutMinutes'] as int? ?? 0,
        activeCalories: json['activeCalories'] as int? ?? 0,
        screenTimeMinutes: json['screenTimeMinutes'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'date': dateKey(date),
        'steps': steps,
        'sleepMinutes': sleepMinutes,
        'workoutMinutes': workoutMinutes,
        'activeCalories': activeCalories,
        'screenTimeMinutes': screenTimeMinutes,
      };

  @override
  bool operator ==(Object other) =>
      other is DailyStats &&
      other.userId == userId &&
      other.date == date &&
      other.steps == steps &&
      other.sleepMinutes == sleepMinutes &&
      other.workoutMinutes == workoutMinutes &&
      other.activeCalories == activeCalories &&
      other.screenTimeMinutes == screenTimeMinutes;

  @override
  int get hashCode => Object.hash(userId, date, steps, sleepMinutes,
      workoutMinutes, activeCalories, screenTimeMinutes);

  // Deliberately omits the health values: never log raw health data.
  @override
  String toString() => 'DailyStats($userId, ${dateKey(date)})';
}
