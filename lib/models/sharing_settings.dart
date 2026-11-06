import 'stat_metric.dart';

/// Which of a user's stats their friends can see.
///
/// Sleep and screen time are private until the user opts in; the activity
/// stats are shared by default because they're what the leaderboards are for.
/// The user always sees all of their own stats.
class SharingSettings {
  const SharingSettings({this.hidden = defaultHidden, this.pausedUntil});

  /// Private by default (AGENTS.md: treat sleep and screen time as private).
  static const defaultHidden = {StatMetric.sleep, StatMetric.screenTime};

  /// Metrics friends can't see.
  final Set<StatMetric> hidden;

  /// While set and in the future, friends see nothing at all.
  final DateTime? pausedUntil;

  bool isPaused(DateTime now) {
    final until = pausedUntil;
    return until != null && now.isBefore(until);
  }

  /// Whether friends can see [metric] at [now].
  bool isShared(StatMetric metric, DateTime now) =>
      !isPaused(now) && !hidden.contains(metric);

  SharingSettings withShared(StatMetric metric, bool shared) => SharingSettings(
    hidden: shared ? (hidden.toSet()..remove(metric)) : {...hidden, metric},
    pausedUntil: pausedUntil,
  );

  /// Pauses all sharing until [until], or resumes it when null.
  SharingSettings withPause(DateTime? until) =>
      SharingSettings(hidden: hidden, pausedUntil: until);

  factory SharingSettings.fromJson(Map<String, dynamic> json) =>
      SharingSettings(
        hidden: {
          for (final name in (json['hidden'] as List? ?? const []))
            ...StatMetric.values.where((m) => m.name == name),
        },
        pausedUntil: json['pausedUntil'] == null
            ? null
            : DateTime.parse(json['pausedUntil'] as String),
      );

  Map<String, dynamic> toJson() => {
    'hidden': [
      for (final m in StatMetric.values)
        if (hidden.contains(m)) m.name,
    ],
    'pausedUntil': pausedUntil?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is SharingSettings &&
      other.pausedUntil == pausedUntil &&
      other.hidden.length == hidden.length &&
      other.hidden.containsAll(hidden);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(hidden), pausedUntil);
}
