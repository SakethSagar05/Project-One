// Plain local calendar dates.
//
// Dates are stored as YYYY-MM-DD strings taken from the device's local
// calendar, with no time-zone conversion. Weeks run Monday to Sunday.
// Days are added by building a new DateTime (year, month, day + n) instead of
// adding a Duration, so daylight-saving changes can never shift a date.

/// Removes the time part of [value].
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Returns [date] moved by [days] calendar days.
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Whole calendar days from [from] to [to] (negative if [to] is earlier).
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Compares two dates by calendar day only.
int compareDates(DateTime a, DateTime b) => daysBetween(b, a).sign;

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The Monday that starts the week containing [date].
DateTime weekStart(DateTime date) {
  final day = dateOnly(date);
  return addDays(day, -(day.weekday - DateTime.monday));
}

/// The Sunday that ends the week containing [date].
DateTime weekEnd(DateTime date) => addDays(weekStart(date), 6);

/// True when [date] falls in the Monday-to-Sunday week that starts on
/// [mondayOfWeek].
bool isInWeek(DateTime date, DateTime mondayOfWeek) {
  final offset = daysBetween(mondayOfWeek, date);
  return offset >= 0 && offset <= 6;
}

/// Formats [date] as the YYYY-MM-DD key stored in SQLite.
String toDateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

final RegExp _dateKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Parses a YYYY-MM-DD key. Throws [FormatException] for anything else,
/// including impossible dates such as 2026-02-30.
DateTime parseDateKey(String key) {
  final match = _dateKeyPattern.firstMatch(key);
  if (match == null) {
    throw FormatException('Expected a YYYY-MM-DD date', key);
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw FormatException('Not a real calendar date', key);
  }
  return date;
}

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const List<String> _weekdayNames = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];

/// "Oct 16"
String formatShort(DateTime date) => '${_monthNames[date.month - 1]} ${date.day}';

/// "Fri Oct 16"
String formatWithWeekday(DateTime date) =>
    '${_weekdayNames[date.weekday - 1]} ${formatShort(date)}';

/// "Oct 26 – Nov 1" for the week that starts on [mondayOfWeek].
String formatWeekRange(DateTime mondayOfWeek) =>
    '${formatShort(mondayOfWeek)} – ${formatShort(addDays(mondayOfWeek, 6))}';

/// Supplies "today". Tests and the demo can pin it to a fixed date.
class AppClock {
  AppClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// A clock that always reports [date].
  factory AppClock.fixed(DateTime date) => AppClock(now: () => date);

  final DateTime Function() _now;

  DateTime today() => dateOnly(_now());
}
