// Weekly progress, plant stages and the garden summary.
//
// Everything here is derived from check-in rows every time it is needed.
// Nothing is stored, so the numbers can never drift away from the data.

import 'local_date.dart';

enum PlantStage { seed, sprout, growing, bloom }

extension PlantStageLabel on PlantStage {
  String get label => switch (this) {
        PlantStage.seed => 'seed',
        PlantStage.sprout => 'sprout',
        PlantStage.growing => 'growing',
        PlantStage.bloom => 'bloom',
      };
}

/// Plant stage from a rate that is already capped at 1.0.
PlantStage plantStageFor(double cappedRate) {
  if (cappedRate <= 0) return PlantStage.seed;
  if (cappedRate < 0.5) return PlantStage.sprout;
  if (cappedRate < 1) return PlantStage.growing;
  return PlantStage.bloom;
}

/// One habit's progress for one week.
class WeekProgress {
  const WeekProgress({required this.count, required this.target});

  /// Distinct check-in dates in the week (can be more than [target]).
  final int count;

  /// The habit's weekly target, 1 to 7.
  final int target;

  /// Days that count toward the target (never more than the target).
  int get countedDays => count > target ? target : count;

  /// Check-ins beyond the target. Shown in the count, not in the plant.
  int get extraDays => count > target ? count - target : 0;

  double get cappedRate => target <= 0 ? 0 : countedDays / target;

  int get percent => (cappedRate * 100).round();

  PlantStage get stage => plantStageFor(cappedRate);

  /// "2 of 4 days"
  String get countLabel => '$count of $target ${target == 1 ? 'day' : 'days'}';

  /// "2 of 4 days · 50%" (plus "+1 extra" when over target).
  String get fullLabel {
    final extra = extraDays > 0 ? ' (+$extraDays extra)' : '';
    return '$countLabel · $percent%$extra';
  }
}

/// Counts distinct calendar dates in [dates] that fall inside the
/// Monday-to-Sunday week containing [anyDayInWeek].
int distinctDatesInWeek(Iterable<DateTime> dates, DateTime anyDayInWeek) {
  final monday = weekStart(anyDayInWeek);
  final keys = <String>{};
  for (final date in dates) {
    if (isInWeek(date, monday)) keys.add(toDateKey(date));
  }
  return keys.length;
}

WeekProgress weekProgress({
  required Iterable<DateTime> checkInDates,
  required int target,
  required DateTime week,
}) =>
    WeekProgress(count: distinctDatesInWeek(checkInDates, week), target: target);

/// Garden-wide summary: each habit contributes at most its own target, so one
/// busy habit cannot cover for another.
class GardenSummary {
  const GardenSummary({required this.countedDays, required this.totalTarget});

  final int countedDays;
  final int totalTarget;

  double get rate => totalTarget == 0 ? 0 : countedDays / totalTarget;
  int get percent => (rate * 100).round();
}

GardenSummary gardenSummary(Iterable<WeekProgress> habits) {
  var counted = 0;
  var target = 0;
  for (final progress in habits) {
    counted += progress.countedDays;
    target += progress.target;
  }
  return GardenSummary(countedDays: counted, totalTarget: target);
}

/// The first Monday of a whole week on or after [startDate]. If the habit
/// started mid-week, that partial week is skipped.
DateTime firstFullWeekStart(DateTime startDate) {
  final start = dateOnly(startDate);
  final monday = weekStart(start);
  return isSameDate(start, monday) ? monday : addDays(monday, 7);
}

/// How many completed, whole weeks (after the start date and before the
/// current week) met the target.
({int met, int total}) weeksOnTarget({
  required Iterable<DateTime> checkInDates,
  required int target,
  required DateTime startDate,
  required DateTime today,
}) {
  final dates = checkInDates.toList();
  var monday = firstFullWeekStart(startDate);
  final currentWeek = weekStart(today);
  var met = 0;
  var total = 0;
  while (compareDates(monday, currentWeek) < 0) {
    total++;
    if (distinctDatesInWeek(dates, monday) >= target) met++;
    monday = addDays(monday, 7);
  }
  return (met: met, total: total);
}
