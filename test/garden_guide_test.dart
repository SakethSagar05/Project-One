// Garden Guide evaluation cases H1–H5 from the proposal, plus the week rules.
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_mastery_league/logic/garden_guide.dart';
import 'package:habit_mastery_league/logic/local_date.dart';

void main() {
  // Controlled "today": Wednesday Oct 28 2026. Current week starts Mon Oct 26.
  final today = DateTime(2026, 10, 28);

  group('suggestWeeklyTarget (cases H1–H5)', () {
    test('H1 normal: counts 2,3,4 with target 5 suggests 3; helper error 1, baseline error 3', () {
      final result = suggestWeeklyTarget(weeklyCounts: [2, 3, 4], currentTarget: 5);
      expect(result.status, GuideStatus.suggestion);
      expect(result.suggestedTarget, 3);
      expect(result.suggestsChange, isTrue);
      expect(result.message, contains('(2, 3, 4)'));

      const actualNextWeek = 2;
      expect(absoluteError(result.suggestedTarget!, actualNextWeek), 1);
      expect(absoluteError(baselineTarget(5), actualNextWeek), 3);
    });

    test('H2 no data: only two eligible weeks gives "Not enough history"', () {
      final result = suggestWeeklyTarget(weeklyCounts: [3, 4], currentTarget: 4);
      expect(result.status, GuideStatus.notEnoughHistory);
      expect(result.suggestedTarget, isNull);
      expect(result.message, contains('Not enough history'));
    });

    test('H2 no data: a habit created this week has no counts', () {
      final counts = completedWeekCounts(
        startDate: DateTime(2026, 10, 26),
        today: today,
        checkInDates: [DateTime(2026, 10, 26), DateTime(2026, 10, 27)],
      );
      expect(counts, isNull);
      final result = suggestWeeklyTarget(weeklyCounts: counts, currentTarget: 3);
      expect(result.status, GuideStatus.notEnoughHistory);
    });

    test('H3 invalid: a weekly count of 9 is rejected', () {
      final result = suggestWeeklyTarget(weeklyCounts: [2, 9, 3], currentTarget: 4);
      expect(result.status, GuideStatus.invalidInput);
      expect(result.suggestedTarget, isNull);
      expect(result.message, contains('9'));
    });

    test('H3 invalid: a weekly count of -1 is rejected', () {
      final result = suggestWeeklyTarget(weeklyCounts: [-1, 2, 3], currentTarget: 4);
      expect(result.status, GuideStatus.invalidInput);
      expect(result.suggestedTarget, isNull);
    });

    test('H4 boundary: counts 0,0,1 average rounds to 0 and is clamped up to 1', () {
      final result = suggestWeeklyTarget(weeklyCounts: [0, 0, 1], currentTarget: 3);
      expect(result.suggestedTarget, 1);
      expect(result.message, contains('raised to the minimum of 1'));
    });

    test('H5 counterexample: counts 4,4,0 give 3 with the mean, 4 with the median', () {
      final mean = suggestWeeklyTarget(weeklyCounts: [4, 4, 0], currentTarget: 4);
      final median = suggestWeeklyTarget(
        weeklyCounts: [4, 4, 0],
        currentTarget: 4,
        method: GuideMethod.median,
      );
      expect(mean.suggestedTarget, 3);
      expect(median.suggestedTarget, 4);
    });

    test('a suggestion equal to the current target is not a change', () {
      final result = suggestWeeklyTarget(weeklyCounts: [3, 3, 3], currentTarget: 3);
      expect(result.suggestedTarget, 3);
      expect(result.suggestsChange, isFalse);
    });

    test('high counts are clamped to 7', () {
      final result = suggestWeeklyTarget(weeklyCounts: [7, 7, 7], currentTarget: 5);
      expect(result.suggestedTarget, 7);
    });

    test('an out-of-range current target is rejected', () {
      final result = suggestWeeklyTarget(weeklyCounts: [3, 3, 3], currentTarget: 0);
      expect(result.status, GuideStatus.invalidInput);
    });
  });

  group('roundHalfUpDivide', () {
    test('rounds halves up', () {
      expect(roundHalfUpDivide(5, 2), 3); // 2.5 -> 3
      expect(roundHalfUpDivide(7, 3), 2); // 2.33 -> 2
      expect(roundHalfUpDivide(8, 3), 3); // 2.67 -> 3
      expect(roundHalfUpDivide(0, 3), 0);
    });
  });

  group('completedWeekCounts', () {
    test('uses the last three whole weeks, oldest first, zero weeks included', () {
      final counts = completedWeekCounts(
        startDate: DateTime(2026, 9, 28), // a Monday
        today: today,
        checkInDates: [
          DateTime(2026, 10, 5), DateTime(2026, 10, 7), // week of Oct 5: 2
          // week of Oct 12: 0
          DateTime(2026, 10, 19), DateTime(2026, 10, 20), DateTime(2026, 10, 25), // 3
          DateTime(2026, 10, 26), // current week: excluded
        ],
      );
      expect(counts, [2, 0, 3]);
    });

    test('the partial starting week is excluded', () {
      // Started Thursday Oct 8: the week of Oct 5 is partial and skipped, so
      // the eligible weeks are Oct 12, 19 = only two. Not enough history.
      final counts = completedWeekCounts(
        startDate: DateTime(2026, 10, 8),
        today: today,
        checkInDates: [DateTime(2026, 10, 8), DateTime(2026, 10, 9)],
      );
      expect(counts, isNull);

      // A week later the same habit has three eligible weeks and the partial
      // week's check-ins are still not counted.
      final later = completedWeekCounts(
        startDate: DateTime(2026, 10, 8),
        today: DateTime(2026, 11, 4),
        checkInDates: [DateTime(2026, 10, 8), DateTime(2026, 10, 9), DateTime(2026, 10, 13)],
      );
      expect(later, [1, 0, 0]);
    });

    test('two check-ins on one date count once', () {
      final day = DateTime(2026, 10, 20);
      final counts = completedWeekCounts(
        startDate: DateTime(2026, 9, 28),
        today: today,
        checkInDates: [day, DateTime(2026, 10, 20, 18, 30), day],
      );
      expect(counts, [0, 0, 1]);
    });

    test('weeks are computed safely across the daylight-saving change', () {
      // US clocks fall back on Sun Nov 1 2026.
      final counts = completedWeekCounts(
        startDate: DateTime(2026, 10, 12),
        today: DateTime(2026, 11, 3),
        checkInDates: [DateTime(2026, 11, 1), DateTime(2026, 10, 26)],
      );
      expect(counts, [0, 0, 2]);
    });
  });

  test('gardenGuideFor combines both steps', () {
    final start = DateTime(2026, 9, 28);
    final dates = <DateTime>[
      addDays(start, 7), addDays(start, 8), // week 2: 2
      addDays(start, 14), addDays(start, 15), addDays(start, 16), // week 3: 3
      addDays(start, 21), addDays(start, 22), addDays(start, 23), addDays(start, 24), // 4
    ];
    final result = gardenGuideFor(
      startDate: start,
      currentTarget: 5,
      checkInDates: dates,
      today: today,
    );
    expect(result.weeklyCounts, [2, 3, 4]);
    expect(result.suggestedTarget, 3);
  });
}
