import 'dart:math' as math;

import '../models/models.dart';

/// Fake people and generated stats for building UI before real data exists.

const mockMe = UserProfile(
  id: 'u_me',
  displayName: 'You',
  username: 'me',
  avatarEmoji: '😎',
  friendCode: 'ME1234',
);

const mockFriends = [
  UserProfile(
      id: 'u_alex',
      displayName: 'Alex',
      username: 'alex.runs',
      avatarEmoji: '🏃',
      friendCode: 'ALEX42'),
  UserProfile(
      id: 'u_bree',
      displayName: 'Bree',
      username: 'breezzz',
      avatarEmoji: '🦥',
      friendCode: 'BREE77'),
  UserProfile(
      id: 'u_chris',
      displayName: 'Chris',
      username: 'chris_lifts',
      avatarEmoji: '🏋️',
      friendCode: 'CHRS09'),
  UserProfile(
      id: 'u_dana',
      displayName: 'Dana',
      username: 'dana.d',
      avatarEmoji: '🎮',
      friendCode: 'DANA55'),
  UserProfile(
      id: 'u_eli',
      displayName: 'Eli',
      username: 'eli_walks',
      avatarEmoji: '🐕',
      friendCode: 'ELI808'),
];

/// Has sent the current user a friend request.
const mockRequester = UserProfile(
  id: 'u_fin',
  displayName: 'Fin',
  username: 'fin.swims',
  avatarEmoji: '🏊',
  friendCode: 'FIN321',
);

/// Not connected yet; findable by friend code.
const mockStranger = UserProfile(
  id: 'u_gia',
  displayName: 'Gia',
  username: 'gia.yoga',
  avatarEmoji: '🧘',
  friendCode: 'GIA999',
);

const mockAllUsers = [mockMe, ...mockFriends, mockRequester, mockStranger];

/// Each person's typical day, so their numbers feel consistent.
class _Persona {
  const _Persona(this.steps, this.sleep, this.workout, this.calories,
      this.screen, this.workoutDaysPerWeek);
  final int steps, sleep, workout, calories, screen;
  final int workoutDaysPerWeek;
}

const _personas = {
  'u_me': _Persona(8000, 430, 35, 420, 260, 4),
  'u_alex': _Persona(12500, 410, 50, 620, 180, 6),
  'u_bree': _Persona(5200, 540, 15, 250, 300, 2),
  'u_chris': _Persona(7500, 450, 70, 560, 210, 5),
  'u_dana': _Persona(4200, 380, 10, 200, 420, 1),
  'u_eli': _Persona(10500, 470, 25, 450, 150, 3),
  'u_fin': _Persona(6800, 460, 45, 480, 200, 4),
  'u_gia': _Persona(7000, 500, 40, 380, 170, 5),
};

/// Generates [days] days of stats ending on [today] for every mock user.
///
/// Deterministic for a given [seed] and [today], so tests are stable.
List<DailyStats> generateMockStats({
  required DateTime today,
  int days = 14,
  int seed = 360,
}) {
  final end = dateOnly(today);
  final result = <DailyStats>[];
  for (var u = 0; u < mockAllUsers.length; u++) {
    final user = mockAllUsers[u];
    final p = _personas[user.id]!;
    final rng = math.Random(seed * 31 + u);
    int vary(int base, double spread) =>
        math.max(0, (base * (1 + (rng.nextDouble() * 2 - 1) * spread)).round());

    for (var i = days - 1; i >= 0; i--) {
      final date = DateTime(end.year, end.month, end.day - i);
      final weekend = date.weekday >= DateTime.saturday;
      final workedOut = rng.nextInt(7) < p.workoutDaysPerWeek;
      final workout = workedOut ? vary(p.workout, 0.4) : 0;
      result.add(DailyStats(
        userId: user.id,
        date: date,
        steps: vary(weekend ? (p.steps * 0.85).round() : p.steps, 0.35),
        sleepMinutes: vary(weekend ? p.sleep + 45 : p.sleep, 0.15),
        workoutMinutes: workout,
        activeCalories: vary(p.calories, 0.25) + workout * 6,
        screenTimeMinutes: vary(weekend ? p.screen + 60 : p.screen, 0.3),
      ));
    }
  }
  return result;
}
