// Garden Guide: the local, rule-based smart helper.
//
// It is NOT a trained or generative model and uses no network.
//
// Recipe (from the approved proposal):
//   1. Take the number of distinct check-in dates in each of the last three
//      whole, completed Monday-to-Sunday weeks on or after the start date.
//      Zero-count weeks are included. The partial starting week and the
//      current week are excluded.
//   2. Average the three counts, round halves up, clamp to 1..7.
// Baseline: keep the user's current target (suggest no change).

import 'local_date.dart';
import 'progress.dart';

/// Number of completed weeks the helper looks at.
const int guideWeeks = 3;
const int minWeeklyTarget = 1;
const int maxWeeklyTarget = 7;

enum GuideStatus { suggestion, notEnoughHistory, invalidInput }

/// The averaging rule. The app uses [mean]; [median] is the alternative we
/// compared in AI_FEATURE.md (case H5).
enum GuideMethod { mean, median }

class GuideResult {
  const GuideResult({
    required this.status,
    required this.currentTarget,
    required this.message,
    this.suggestedTarget,
    this.weeklyCounts = const [],
  });

  final GuideStatus status;
  final int currentTarget;

  /// Only set when [status] is [GuideStatus.suggestion].
  final int? suggestedTarget;

  /// The week counts the suggestion was based on, oldest first.
  final List<int> weeklyCounts;

  /// Plain-language explanation shown on the card.
  final String message;

  bool get hasSuggestion => status == GuideStatus.suggestion;

  bool get suggestsChange =>
      hasSuggestion && suggestedTarget != null && suggestedTarget != currentTarget;
}

/// Step 1. Distinct check-in dates in each of the last [weeks] completed
/// whole weeks, oldest first. Returns null when there are fewer than [weeks]
/// eligible weeks (not enough history).
List<int>? completedWeekCounts({
  required DateTime startDate,
  required DateTime today,
  required Iterable<DateTime> checkInDates,
  int weeks = guideWeeks,
}) {
  final currentWeek = weekStart(today);
  final firstEligible = firstFullWeekStart(startDate);
  final eligibleWeeks = daysBetween(firstEligible, currentWeek) ~/ 7;
  if (eligibleWeeks < weeks) return null;

  final dates = checkInDates.toList();
  return [
    for (var i = weeks; i >= 1; i--)
      distinctDatesInWeek(dates, addDays(currentWeek, -7 * i)),
  ];
}

/// Integer division that rounds halves up (for non-negative numbers).
int roundHalfUpDivide(int numerator, int denominator) =>
    (2 * numerator + denominator) ~/ (2 * denominator);

int _median(List<int> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return roundHalfUpDivide(sorted[mid - 1] + sorted[mid], 2);
}

/// Step 2. Turns weekly counts into a suggested weekly target.
GuideResult suggestWeeklyTarget({
  required List<int>? weeklyCounts,
  required int currentTarget,
  GuideMethod method = GuideMethod.mean,
}) {
  if (currentTarget < minWeeklyTarget || currentTarget > maxWeeklyTarget) {
    return GuideResult(
      status: GuideStatus.invalidInput,
      currentTarget: currentTarget,
      message: 'The current target ($currentTarget) is outside 1 to 7, '
          'so no suggestion was made.',
    );
  }
  if (weeklyCounts == null || weeklyCounts.length < guideWeeks) {
    return GuideResult(
      status: GuideStatus.notEnoughHistory,
      currentTarget: currentTarget,
      message: 'Not enough history yet. Garden Guide needs $guideWeeks full '
          'weeks (Mon–Sun) after the start date. Keeping your target of '
          '$currentTarget.',
    );
  }
  final recent = weeklyCounts.sublist(weeklyCounts.length - guideWeeks);
  for (final count in recent) {
    if (count < 0 || count > 7) {
      return GuideResult(
        status: GuideStatus.invalidInput,
        currentTarget: currentTarget,
        weeklyCounts: recent,
        message: 'A weekly count of $count is impossible (it must be 0 to 7 '
            'days), so no suggestion was made.',
      );
    }
  }

  final sum = recent.fold<int>(0, (total, c) => total + c);
  final raw = method == GuideMethod.mean
      ? roundHalfUpDivide(sum, recent.length)
      : _median(recent);
  final suggested = raw.clamp(minWeeklyTarget, maxWeeklyTarget);

  final countsText = recent.join(', ');
  final String basis;
  if (method == GuideMethod.mean) {
    final average = (sum / recent.length).toStringAsFixed(1);
    basis = 'Average of your last $guideWeeks full weeks ($countsText) = '
        '$average, rounded to $raw';
  } else {
    basis = 'Median of your last $guideWeeks full weeks ($countsText) = $raw';
  }
  final clampNote =
      raw < minWeeklyTarget ? ', raised to the minimum of $minWeeklyTarget' : '';
  final daysWord = suggested == 1 ? 'day' : 'days';

  return GuideResult(
    status: GuideStatus.suggestion,
    currentTarget: currentTarget,
    suggestedTarget: suggested,
    weeklyCounts: recent,
    message: '$basis$clampNote. Suggested target: $suggested $daysWord a week.',
  );
}

/// Convenience used by the Habit detail screen.
GuideResult gardenGuideFor({
  required DateTime startDate,
  required int currentTarget,
  required Iterable<DateTime> checkInDates,
  required DateTime today,
  GuideMethod method = GuideMethod.mean,
}) =>
    suggestWeeklyTarget(
      weeklyCounts: completedWeekCounts(
        startDate: startDate,
        today: today,
        checkInDates: checkInDates,
      ),
      currentTarget: currentTarget,
      method: method,
    );

/// The baseline "predictor": keep the current target.
int baselineTarget(int currentTarget) => currentTarget;

/// Used in the evaluation: |predicted - actual|.
int absoluteError(int predicted, int actual) => (predicted - actual).abs();
