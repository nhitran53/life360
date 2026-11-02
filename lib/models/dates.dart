/// Date helpers shared by models and repositories.
///
/// All stats are bucketed by local calendar day, and weeks start on Monday.
library;

/// Strips the time part, keeping only the local calendar day.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The Monday that starts the week containing [d].
DateTime startOfWeek(DateTime d) {
  final day = dateOnly(d);
  return DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));
}

/// `yyyy-mm-dd`, used as a stable key (e.g. a Firestore document id later).
String dateKey(DateTime d) {
  final day = dateOnly(d);
  final m = day.month.toString().padLeft(2, '0');
  final dd = day.day.toString().padLeft(2, '0');
  return '${day.year}-$m-$dd';
}
