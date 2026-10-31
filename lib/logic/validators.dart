// Validation rules shared by the forms (inline errors) and the repository
// (last line of defence before SQLite). Each returns null when valid, or a
// message to show the user.

import 'local_date.dart';

const int maxTitleLength = 60;
const int maxCategoryLength = 30;
const int maxNoteLength = 140;

String? validateTitle(String? value) {
  final title = value?.trim() ?? '';
  if (title.isEmpty) return 'Give the habit a title.';
  if (title.length > maxTitleLength) {
    return 'Keep the title under $maxTitleLength characters.';
  }
  return null;
}

String? validateCategory(String? value) {
  final category = value?.trim() ?? '';
  if (category.length > maxCategoryLength) {
    return 'Keep the category under $maxCategoryLength characters.';
  }
  return null;
}

String? validateWeeklyTarget(int target) {
  if (target < 1 || target > 7) return 'Weekly target must be 1 to 7 days.';
  return null;
}

String? validateStartDate(DateTime start, DateTime today) {
  if (compareDates(start, today) > 0) return "Start date can't be in the future.";
  return null;
}

String? validateNote(String? value) {
  if ((value?.trim().length ?? 0) > maxNoteLength) {
    return 'Keep notes under $maxNoteLength characters.';
  }
  return null;
}

/// Rules for a check-in date against its habit.
String? validateCheckInDate({
  required DateTime date,
  required DateTime habitStart,
  required DateTime today,
}) {
  if (compareDates(date, today) > 0) return "A check-in can't be in the future.";
  if (compareDates(date, habitStart) < 0) {
    return "A check-in can't be before the habit started (${formatShort(habitStart)}).";
  }
  return null;
}
