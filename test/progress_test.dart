import 'package:flutter_test/flutter_test.dart';
import 'package:habit_mastery_league/logic/local_date.dart';
import 'package:habit_mastery_league/logic/progress.dart';

void main() {
  final wednesday = DateTime(2026, 10, 28);

  group('local dates and weeks', () {
    test('weeks start on Monday, including when today is Sunday', () {
      expect(weekStart(wednesday), DateTime(2026, 10, 26));
      expect(weekStart(DateTime(2026, 11, 1)), DateTime(2026, 10, 26)); // Sunday
      expect(weekStart(DateTime(2026, 10, 26)), DateTime(2026, 10, 26)); // Monday
      expect(weekEnd(wednesday), DateTime(2026, 11, 1));
    });

    test('date keys round-trip and reject impossible dates', () {
      expect(toDateKey(DateTime(2026, 3, 7)), '2026-03-07');
      expect(parseDateKey('2026-03-07'), DateTime(2026, 3, 7));
      expect(() => parseDateKey('2026-02-30'), throwsFormatException);
      expect(() => parseDateKey('10/16/2026'), throwsFormatException);
    });

    test('addDays is not shifted by daylight saving', () {
      expect(addDays(DateTime(2026, 10, 31), 1), DateTime(2026, 11, 1));
      expect(addDays(DateTime(2026, 11, 1), 1), DateTime(2026, 11, 2));
      expect(daysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 15)), 14);
    });
  });

  group('weekly rate (proposal acceptance example)', () {
    test('target 4: two dates = 50%, a repeat date stays 50%, deleting one = 25%', () {
      final dates = [DateTime(2026, 10, 26), DateTime(2026, 10, 27)];
      var progress = weekProgress(checkInDates: dates, target: 4, week: wednesday);
      expect(progress.count, 2);
      expect(progress.percent, 50);
      expect(progress.countLabel, '2 of 4 days');

      // Tapping check-in again on one of those dates does not change anything.
      final withRepeat = [...dates, DateTime(2026, 10, 27)];
      progress = weekProgress(checkInDates: withRepeat, target: 4, week: wednesday);
      expect(progress.percent, 50);

      // Deleting one of the two dates.
      progress = weekProgress(checkInDates: [dates.first], target: 4, week: wednesday);
      expect(progress.percent, 25);
    });

    test('check-ins from other weeks are ignored', () {
      final dates = [DateTime(2026, 10, 25), DateTime(2026, 11, 2), DateTime(2026, 10, 28)];
      expect(distinctDatesInWeek(dates, wednesday), 1);
    });

    test('extra check-ins stay in the count but the rate and plant are capped', () {
      const progress = WeekProgress(count: 5, target: 4);
      expect(progress.countedDays, 4);
      expect(progress.extraDays, 1);
      expect(progress.percent, 100);
      expect(progress.stage, PlantStage.bloom);
      expect(progress.fullLabel, '5 of 4 days · 100% (+1 extra)');
    });
  });

  test('plant stages follow the capped rate', () {
    expect(plantStageFor(0), PlantStage.seed);
    expect(plantStageFor(0.25), PlantStage.sprout);
    expect(plantStageFor(0.5), PlantStage.growing);
    expect(plantStageFor(0.99), PlantStage.growing);
    expect(plantStageFor(1), PlantStage.bloom);
  });

  test('garden summary caps each habit at its own target', () {
    final summary = gardenSummary(const [
      WeekProgress(count: 7, target: 3), // counts as 3, not 7
      WeekProgress(count: 0, target: 3),
    ]);
    expect(summary.countedDays, 3);
    expect(summary.totalTarget, 6);
    expect(summary.percent, 50);
  });

  test('weeksOnTarget only counts completed whole weeks', () {
    final result = weeksOnTarget(
      checkInDates: [
        DateTime(2026, 10, 12), DateTime(2026, 10, 13), // week of Oct 12: 2 (met)
        DateTime(2026, 10, 19), // week of Oct 19: 1 (missed)
        DateTime(2026, 10, 26), DateTime(2026, 10, 27), // current week: ignored
      ],
      target: 2,
      startDate: DateTime(2026, 10, 12),
      today: wednesday,
    );
    expect(result.total, 2);
    expect(result.met, 1);
  });
}
