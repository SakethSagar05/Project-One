import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_scope.dart';
import 'data/app_database.dart';
import 'data/habit_repository.dart';
import 'data/settings_store.dart';
import 'logic/local_date.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final clock = AppClock();
    final db = await AppDatabase.open();
    final prefs = await SharedPreferences.getInstance();
    runApp(
      HabitMasteryApp(
        services: AppServices(
          repository: HabitRepository(db, clock),
          settings: SettingsStore(prefs),
          clock: clock,
        ),
      ),
    );
  } catch (e) {
    runApp(StartupErrorApp(message: '$e'));
  }
}

/// Shown only if local storage cannot be opened at all.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Habit Mastery League could not open its local storage.\n\n$message',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
