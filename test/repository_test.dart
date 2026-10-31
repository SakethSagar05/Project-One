// SQLite rules for Habit and CheckIn, run against a real SQLite engine
// through sqflite_common_ffi (no device needed).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_mastery_league/data/app_database.dart';
import 'package:habit_mastery_league/data/habit_repository.dart';
import 'package:habit_mastery_league/logic/local_date.dart';
import 'package:habit_mastery_league/models/check_in.dart';
import 'package:habit_mastery_league/models/habit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  final today = DateTime(2026, 10, 28); // Wednesday
  late Database db;
  late HabitRepository repo;

  Habit draft({
    String title = 'Read 10 pages',
    String category = 'Study',
    int target = 4,
    DateTime? start,
  }) =>
      Habit(
        title: title,
        category: category,
        weeklyTarget: target,
        startedLocalDate: start ?? DateTime(2026, 10, 1),
      );

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      singleInstance: false,
    );
    repo = HabitRepository(db, AppClock.fixed(today));
  });

  tearDown(() async => db.close());

  group('Habit CRUD', () {
    test('create, read, update and delete', () async {
      final created = await repo.createHabit(draft());
      expect(created.id, isNotNull);

      final loaded = await repo.getHabit(created.id!);
      expect(loaded!.title, 'Read 10 pages');
      expect(loaded.startedLocalDate, DateTime(2026, 10, 1));

      await repo.updateHabit(loaded.copyWith(title: 'Read 20 pages', weeklyTarget: 5));
      final updated = await repo.getHabit(created.id!);
      expect(updated!.title, 'Read 20 pages');
      expect(updated.weeklyTarget, 5);

      await repo.deleteHabit(created.id!);
      expect(await repo.getHabit(created.id!), isNull);
    });

    test('T1: an empty title is rejected and nothing is saved', () async {
      await expectLater(
        repo.createHabit(draft(title: '   ')),
        throwsA(isA<ValidationException>()),
      );
      expect(await repo.getHabits(), isEmpty);
    });

    test('weekly target must be 1 to 7', () async {
      await expectLater(repo.createHabit(draft(target: 0)), throwsA(isA<ValidationException>()));
      await expectLater(repo.createHabit(draft(target: 8)), throwsA(isA<ValidationException>()));
    });

    test('start date cannot be in the future', () async {
      await expectLater(
        repo.createHabit(draft(start: DateTime(2026, 10, 29))),
        throwsA(isA<ValidationException>()),
      );
    });

    test('an empty category becomes General; category filter works', () async {
      await repo.createHabit(draft(title: 'A', category: ''));
      await repo.createHabit(draft(title: 'B', category: 'Health'));
      expect(await repo.getCategories(), ['General', 'Health']);
      final health = await repo.getHabits(category: 'Health');
      expect(health.map((h) => h.title), ['B']);
    });

    test('the database CHECK constraint also guards the target', () async {
      await expectLater(
        db.insert('Habit', {
          'title': 'x',
          'category': 'y',
          'weeklyTarget': 9,
          'startedLocalDate': '2026-10-01',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('moving the start date after existing check-ins is blocked', () async {
      final habit = await repo.createHabit(draft());
      await repo.addCheckIn(habitId: habit.id!, date: DateTime(2026, 10, 5));
      await expectLater(
        repo.updateHabit(habit.copyWith(startedLocalDate: DateTime(2026, 10, 10))),
        throwsA(isA<ValidationException>()),
      );
      expect((await repo.getHabit(habit.id!))!.startedLocalDate, DateTime(2026, 10, 1));
    });
  });

  group('CheckIn CRUD and rules', () {
    late Habit habit;
    setUp(() async => habit = await repo.createHabit(draft()));

    test('create, read, update and delete', () async {
      final c = await repo.addCheckIn(habitId: habit.id!, date: DateTime(2026, 10, 26), note: ' ok ');
      var all = await repo.getCheckIns(habit.id!);
      expect(all, hasLength(1));
      expect(all.single.note, 'ok');

      await repo.updateCheckIn(CheckIn(
        id: c.id,
        habitId: habit.id!,
        localDate: DateTime(2026, 10, 27),
        note: 'moved',
      ));
      all = await repo.getCheckIns(habit.id!);
      expect(all.single.localDate, DateTime(2026, 10, 27));
      expect(all.single.note, 'moved');

      await repo.deleteCheckIn(c.id!);
      expect(await repo.getCheckIns(habit.id!), isEmpty);
    });

    test('T2: a second check-in on the same day is rejected, one row stays', () async {
      await repo.addCheckIn(habitId: habit.id!, date: today);
      await expectLater(
        repo.addCheckIn(habitId: habit.id!, date: today),
        throwsA(isA<DuplicateCheckInException>().having(
          (e) => e.message,
          'message',
          'Already checked in on Oct 28. Nothing was changed.',
        )),
      );
      expect(await repo.getCheckIns(habit.id!), hasLength(1));
    });

    test('T3: editing a check-in onto a used date is rejected and the original kept', () async {
      await repo.addCheckIn(habitId: habit.id!, date: DateTime(2026, 10, 26));
      final second = await repo.addCheckIn(habitId: habit.id!, date: DateTime(2026, 10, 27));
      await expectLater(
        repo.updateCheckIn(second.copyWith(localDate: DateTime(2026, 10, 26))),
        throwsA(isA<DuplicateCheckInException>()),
      );
      final dates = (await repo.getCheckIns(habit.id!)).map((c) => c.localDate);
      expect(dates, containsAll([DateTime(2026, 10, 26), DateTime(2026, 10, 27)]));
    });

    test('the UNIQUE constraint backs up the code check', () async {
      await db.insert('CheckIn', {'habitId': habit.id, 'localDate': '2026-10-20'});
      await expectLater(
        db.insert('CheckIn', {'habitId': habit.id, 'localDate': '2026-10-20'}),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('check-ins cannot be in the future or before the start date', () async {
      await expectLater(
        repo.addCheckIn(habitId: habit.id!, date: DateTime(2026, 10, 29)),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repo.addCheckIn(habitId: habit.id!, date: DateTime(2026, 9, 30)),
        throwsA(isA<ValidationException>()),
      );
    });

    test('T7: deleting a habit cascades to its check-ins and reports the count', () async {
      await repo.addCheckIn(habitId: habit.id!, date: DateTime(2026, 10, 26));
      await repo.addCheckIn(habitId: habit.id!, date: DateTime(2026, 10, 27));
      expect(await repo.countCheckIns(habit.id!), 2);

      final removed = await repo.deleteHabit(habit.id!);
      expect(removed, 2);
      final orphans = await db.query('CheckIn', where: 'habitId = ?', whereArgs: [habit.id]);
      expect(orphans, isEmpty);
    });

    test('getCheckInDatesBetween groups dates by habit', () async {
      final other = await repo.createHabit(draft(title: 'Walk'));
      await repo.addCheckIn(habitId: habit.id!, date: DateTime(2026, 10, 26));
      await repo.addCheckIn(habitId: other.id!, date: DateTime(2026, 10, 27));
      await repo.addCheckIn(habitId: other.id!, date: DateTime(2026, 10, 20)); // last week
      final map = await repo.getCheckInDatesBetween(DateTime(2026, 10, 26), DateTime(2026, 11, 1));
      expect(map[habit.id], [DateTime(2026, 10, 26)]);
      expect(map[other.id], [DateTime(2026, 10, 27)]);
    });
  });

  test('sample habit has last three full weeks of 2, 3 and 4 check-ins', () async {
    final sample = await repo.addSampleHabit();
    expect(sample.title, contains('sample'));
    final checkIns = await repo.getCheckIns(sample.id!);
    expect(checkIns, hasLength(10));
    expect(checkIns.every((c) => compareDates(c.localDate, today) <= 0), isTrue);
  });

  test('T5 (storage part): data survives closing and reopening the database', () async {
    final dir = await Directory.systemTemp.createTemp('hml_restart');
    final path = '${dir.path}/restart.db';
    try {
      var fileDb = await AppDatabase.open(factory: databaseFactoryFfi, path: path, singleInstance: false);
      var fileRepo = HabitRepository(fileDb, AppClock.fixed(today));
      final habit = await fileRepo.createHabit(draft());
      await fileRepo.addCheckIn(habitId: habit.id!, date: DateTime(2026, 10, 26));
      await fileDb.close();

      fileDb = await AppDatabase.open(factory: databaseFactoryFfi, path: path, singleInstance: false);
      fileRepo = HabitRepository(fileDb, AppClock.fixed(today));
      expect((await fileRepo.getHabits()).single.title, 'Read 10 pages');
      expect(await fileRepo.getCheckInDates(habit.id!), [DateTime(2026, 10, 26)]);
      await fileDb.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
