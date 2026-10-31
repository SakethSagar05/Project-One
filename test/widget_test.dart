// Widget tests for the main flows: empty state, T1 (empty title), creating a
// habit, and T2 (tapping "Check in today" twice).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_mastery_league/app.dart';
import 'package:habit_mastery_league/app_scope.dart';
import 'package:habit_mastery_league/data/app_database.dart';
import 'package:habit_mastery_league/data/habit_repository.dart';
import 'package:habit_mastery_league/data/settings_store.dart';
import 'package:habit_mastery_league/logic/local_date.dart';
import 'package:habit_mastery_league/models/habit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  final today = DateTime(2026, 10, 28);
  late Database db;
  late AppServices services;

  /// Lets real database futures finish, then draws a frame. Repeated a few
  /// times because one screen load can chain several queries.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> startApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      db = await AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
        singleInstance: false,
      );
      final clock = AppClock.fixed(today);
      services = AppServices(
        repository: HabitRepository(db, clock),
        settings: SettingsStore(prefs),
        clock: clock,
      );
    });
    await tester.pumpWidget(HabitMasteryApp(services: services));
    await settle(tester);
  }

  Future<void> closeDb(WidgetTester tester) async {
    await tester.runAsync(() => db.close());
  }

  testWidgets('empty garden shows the empty state', (tester) async {
    await startApp(tester);
    expect(find.text('Your garden is empty'), findsOneWidget);
    expect(find.text('Plant a habit'), findsOneWidget);
    await closeDb(tester);
  });

  testWidgets('T1: saving with an empty title shows an error and saves nothing',
      (tester) async {
    await startApp(tester);
    await tester.tap(find.text('New habit'));
    await settle(tester);

    await tester.tap(find.text('Save habit'));
    await settle(tester);

    expect(find.text('Give the habit a title.'), findsOneWidget);
    final habits = await tester.runAsync(() => services.repository.getHabits());
    expect(habits, isEmpty);
    await closeDb(tester);
  });

  testWidgets('creating a habit adds a tile to the garden', (tester) async {
    await startApp(tester);
    await tester.tap(find.text('New habit'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Read 10 pages');
    await tester.tap(find.text('Study'));
    await tester.pump();
    await tester.tap(find.text('Save habit'));
    await settle(tester);

    expect(find.text('Read 10 pages'), findsOneWidget);
    expect(find.text('0 of 3 days · 0%'), findsOneWidget);
    await closeDb(tester);
  });

  testWidgets('T2: tapping "Check in today" twice keeps one check-in', (tester) async {
    await startApp(tester);
    final habit = await tester.runAsync(() => services.repository.createHabit(
          Habit(
            title: 'Stretch',
            category: 'Health',
            weeklyTarget: 4,
            startedLocalDate: DateTime(2026, 10, 1),
          ),
        ));
    // Reload the garden by opening and closing settings.
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Stretch'));
    await settle(tester);

    await tester.tap(find.text('Check in today'));
    await settle(tester);
    expect(find.text('1 of 4 days · 25%'), findsOneWidget);

    await tester.tap(find.text('Check in today'));
    await settle(tester);
    expect(find.text('Already checked in on Oct 28. Nothing was changed.'), findsOneWidget);
    expect(find.text('1 of 4 days · 25%'), findsOneWidget);

    final rows = await tester.runAsync(() => services.repository.getCheckIns(habit!.id!));
    expect(rows, hasLength(1));
    await closeDb(tester);
  });

  testWidgets('Garden Guide card says "Not enough history" for a new habit',
      (tester) async {
    await startApp(tester);
    await tester.runAsync(() => services.repository.createHabit(
          Habit(
            title: 'Journal',
            category: 'Mindfulness',
            weeklyTarget: 3,
            startedLocalDate: DateTime(2026, 10, 26),
          ),
        ));
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Journal'));
    await settle(tester);
    expect(find.text('Rule-based helper'), findsOneWidget);
    expect(find.textContaining('Not enough history'), findsOneWidget);
    await closeDb(tester);
  });
}
