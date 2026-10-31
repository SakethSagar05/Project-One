import 'package:sqflite/sqflite.dart';

import '../logic/local_date.dart';
import '../logic/validators.dart';
import '../models/check_in.dart';
import '../models/habit.dart';

/// A rule was broken. [message] is safe to show to the user as-is.
class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A second check-in for the same habit on the same date.
class DuplicateCheckInException extends ValidationException {
  DuplicateCheckInException(DateTime date)
      : super('Already checked in on ${formatShort(date)}. Nothing was changed.');
}

/// The database write itself failed. The screen keeps the user's input.
class StorageException implements Exception {
  const StorageException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => message;
}

/// All reads and writes for Habit and CheckIn. Every query uses
/// parameterized arguments (whereArgs / ? placeholders), never string
/// concatenation of user input.
class HabitRepository {
  HabitRepository(this._db, this._clock);

  final Database _db;
  final AppClock _clock;

  static const String defaultCategory = 'General';

  // ---------------------------------------------------------------- Habit

  Future<List<Habit>> getHabits({String? category}) async {
    final rows = await _db.query(
      'Habit',
      where: category == null ? null : 'category = ?',
      whereArgs: category == null ? null : [category],
      orderBy: 'title COLLATE NOCASE',
    );
    return rows.map(Habit.fromMap).toList();
  }

  Future<List<String>> getCategories() async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT category FROM Habit ORDER BY category COLLATE NOCASE',
    );
    return rows.map((row) => row['category'] as String).toList();
  }

  Future<Habit?> getHabit(int id) async {
    final rows = await _db.query('Habit', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Habit.fromMap(rows.first);
  }

  Future<Habit> createHabit(Habit draft) async {
    final habit = _cleanHabit(draft);
    final id = await _write(
      () => _db.insert('Habit', habit.toMap()..remove('id')),
    );
    return habit.copyWith(id: id);
  }

  Future<void> updateHabit(Habit draft) async {
    final id = draft.id;
    if (id == null) throw ArgumentError('updateHabit needs a saved habit');
    final habit = _cleanHabit(draft);

    // Start-date policy: block the change if it would orphan check-ins.
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n, MIN(localDate) AS first FROM CheckIn '
      'WHERE habitId = ? AND localDate < ?',
      [id, toDateKey(habit.startedLocalDate)],
    );
    final early = (rows.first['n'] as int?) ?? 0;
    if (early > 0) {
      final first = parseDateKey(rows.first['first'] as String);
      final noun = early == 1 ? 'check-in is' : 'check-ins are';
      throw ValidationException(
        '$early $noun dated before ${formatShort(habit.startedLocalDate)} '
        '(earliest ${formatShort(first)}). Fix or delete them before moving '
        'the start date.',
      );
    }

    final changed = await _write(
      () => _db.update('Habit', habit.toMap()..remove('id'),
          where: 'id = ?', whereArgs: [id]),
    );
    if (changed == 0) throw const StorageException('That habit no longer exists.');
  }

  /// How many check-ins a delete would remove (shown in the confirm dialog).
  Future<int> countCheckIns(int habitId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM CheckIn WHERE habitId = ?',
      [habitId],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Deletes the habit; ON DELETE CASCADE removes its check-ins.
  /// Returns the number of check-ins that were removed with it.
  Future<int> deleteHabit(int habitId) {
    return _write(() => _db.transaction((txn) async {
          final rows = await txn.rawQuery(
            'SELECT COUNT(*) AS n FROM CheckIn WHERE habitId = ?',
            [habitId],
          );
          final removed = (rows.first['n'] as int?) ?? 0;
          await txn.delete('Habit', where: 'id = ?', whereArgs: [habitId]);
          return removed;
        }));
  }

  // -------------------------------------------------------------- CheckIn

  /// Check-ins for one habit, newest first. [from] and [to] are inclusive.
  Future<List<CheckIn>> getCheckIns(int habitId, {DateTime? from, DateTime? to}) async {
    final where = StringBuffer('habitId = ?');
    final args = <Object>[habitId];
    if (from != null) {
      where.write(' AND localDate >= ?');
      args.add(toDateKey(from));
    }
    if (to != null) {
      where.write(' AND localDate <= ?');
      args.add(toDateKey(to));
    }
    final rows = await _db.query(
      'CheckIn',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'localDate DESC',
    );
    return rows.map(CheckIn.fromMap).toList();
  }

  Future<List<DateTime>> getCheckInDates(int habitId) async {
    final checkIns = await getCheckIns(habitId);
    return checkIns.map((c) => c.localDate).toList();
  }

  /// Check-in dates for every habit between [from] and [to] (inclusive),
  /// grouped by habitId. Used by the Garden screen.
  Future<Map<int, List<DateTime>>> getCheckInDatesBetween(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'CheckIn',
      columns: ['habitId', 'localDate'],
      where: 'localDate >= ? AND localDate <= ?',
      whereArgs: [toDateKey(from), toDateKey(to)],
    );
    final result = <int, List<DateTime>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row['habitId'] as int, () => [])
          .add(parseDateKey(row['localDate'] as String));
    }
    return result;
  }

  Future<CheckIn> addCheckIn({
    required int habitId,
    required DateTime date,
    String? note,
  }) async {
    final day = dateOnly(date);
    await _checkCheckInRules(habitId: habitId, date: day);
    final checkIn = CheckIn(habitId: habitId, localDate: day, note: _cleanNote(note));
    try {
      final id = await _db.insert('CheckIn', checkIn.toMap()..remove('id'));
      return CheckIn(id: id, habitId: habitId, localDate: day, note: checkIn.note);
    } on DatabaseException catch (e) {
      // Backstop: the UNIQUE constraint caught a duplicate the code check missed.
      if (e.isUniqueConstraintError()) throw DuplicateCheckInException(day);
      throw StorageException('Could not save the check-in. Please try again.', e);
    }
  }

  Future<void> updateCheckIn(CheckIn checkIn) async {
    final id = checkIn.id;
    if (id == null) throw ArgumentError('updateCheckIn needs a saved check-in');
    final day = dateOnly(checkIn.localDate);
    await _checkCheckInRules(habitId: checkIn.habitId, date: day, ignoreId: id);
    try {
      final changed = await _db.update(
        'CheckIn',
        {'localDate': toDateKey(day), 'note': _cleanNote(checkIn.note)},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw const StorageException('That check-in no longer exists.');
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw DuplicateCheckInException(day);
      throw StorageException('Could not save the check-in. Please try again.', e);
    }
  }

  Future<void> deleteCheckIn(int id) async {
    await _write(() => _db.delete('CheckIn', where: 'id = ?', whereArgs: [id]));
  }

  // ---------------------------------------------------------- Sample data

  /// Adds one clearly labeled, fictional habit with past check-ins so the
  /// Garden Guide card can be demonstrated without waiting three weeks.
  /// Its last three full weeks have 2, 3 and 4 check-ins (case H1).
  Future<Habit> addSampleHabit() async {
    final today = _clock.today();
    final currentWeek = weekStart(today);
    final start = addDays(currentWeek, -28); // a Monday four weeks ago
    // Day offsets (0 = Monday) per week, oldest first.
    const weeks = <List<int>>[
      [2], // week 1: 1 day (not used by the helper)
      [0, 3], // week 2: 2 days
      [0, 2, 4], // week 3: 3 days
      [0, 1, 3, 5], // week 4: 4 days
    ];
    return _write(() => _db.transaction((txn) async {
          final habit = Habit(
            title: 'Sketching (sample)',
            category: 'Creative',
            weeklyTarget: 5,
            startedLocalDate: start,
            motivation: 'Fictional sample data for the demo.',
          );
          final id = await txn.insert('Habit', habit.toMap()..remove('id'));
          for (var w = 0; w < weeks.length; w++) {
            for (final offset in weeks[w]) {
              final date = addDays(start, w * 7 + offset);
              await txn.insert('CheckIn', {
                'habitId': id,
                'localDate': toDateKey(date),
                'note': 'Sample',
              });
            }
          }
          return habit.copyWith(id: id);
        }));
  }

  // -------------------------------------------------------------- helpers

  Habit _cleanHabit(Habit draft) {
    final today = _clock.today();
    final error = validateTitle(draft.title) ??
        validateCategory(draft.category) ??
        validateWeeklyTarget(draft.weeklyTarget) ??
        validateStartDate(draft.startedLocalDate, today) ??
        validateNote(draft.motivation);
    if (error != null) throw ValidationException(error);

    final category = draft.category.trim();
    return Habit(
      id: draft.id,
      title: draft.title.trim(),
      category: category.isEmpty ? defaultCategory : category,
      weeklyTarget: draft.weeklyTarget,
      startedLocalDate: dateOnly(draft.startedLocalDate),
      motivation: _cleanNote(draft.motivation),
    );
  }

  String? _cleanNote(String? note) {
    final trimmed = note?.trim() ?? '';
    if (trimmed.length > maxNoteLength) {
      throw const ValidationException('Keep notes under $maxNoteLength characters.');
    }
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _checkCheckInRules({
    required int habitId,
    required DateTime date,
    int? ignoreId,
  }) async {
    final habit = await getHabit(habitId);
    if (habit == null) throw const ValidationException('That habit no longer exists.');
    final error = validateCheckInDate(
      date: date,
      habitStart: habit.startedLocalDate,
      today: _clock.today(),
    );
    if (error != null) throw ValidationException(error);

    final rows = await _db.query(
      'CheckIn',
      columns: ['id'],
      where: ignoreId == null
          ? 'habitId = ? AND localDate = ?'
          : 'habitId = ? AND localDate = ? AND id != ?',
      whereArgs: [habitId, toDateKey(date), if (ignoreId != null) ignoreId],
    );
    if (rows.isNotEmpty) throw DuplicateCheckInException(date);
  }

  /// Runs a write and turns low-level database errors into a message the
  /// screen can show while keeping the user's input.
  Future<T> _write<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException catch (e) {
      throw StorageException('Could not save to the device. Your input was kept.', e);
    }
  }
}
