import '../models/models.dart';
import 'health_source.dart';

/// In-memory [HealthSource] for tests and demos without a health hub.
class MockHealthSource implements HealthSource {
  MockHealthSource({
    this.name = 'Apple Health',
    this.initial = HealthConnection.notConnected,
    this.grantOnConnect = true,
    Map<DateTime, DailyStats>? days,
  }) : _days = days ?? {};

  @override
  final String name;

  /// What [connection] reports before [connect] is called.
  final HealthConnection initial;

  /// Whether the fake permission sheet grants access.
  final bool grantOnConnect;

  /// Stats keyed by local midnight. Missing days read as zero.
  final Map<DateTime, DailyStats> _days;

  late HealthConnection _state = initial;
  int installCalls = 0;

  @override
  Future<HealthConnection> connection() async => _state;

  @override
  Future<bool> connect() async {
    if (_state == HealthConnection.unsupported ||
        _state == HealthConnection.needsInstall) {
      return false;
    }
    if (grantOnConnect) _state = HealthConnection.connected;
    return grantOnConnect;
  }

  @override
  Future<void> disconnect() async {
    if (_state == HealthConnection.connected) {
      _state = HealthConnection.notConnected;
    }
  }

  @override
  Future<void> installProvider() async {
    installCalls++;
  }

  @override
  Future<List<DailyStats>> readDays(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (_state != HealthConnection.connected) return const [];
    final last = dateOnly(to);
    return [
      for (
        var day = dateOnly(from);
        !day.isAfter(last);
        day = DateTime(day.year, day.month, day.day + 1)
      )
        (_days[day] ?? DailyStats(userId: userId, date: day)).withUser(userId),
    ];
  }
}

extension on DailyStats {
  DailyStats withUser(String id) => id == userId
      ? this
      : DailyStats(
          userId: id,
          date: date,
          steps: steps,
          sleepMinutes: sleepMinutes,
          workoutMinutes: workoutMinutes,
          activeCalories: activeCalories,
          screenTimeMinutes: screenTimeMinutes,
        );
}
