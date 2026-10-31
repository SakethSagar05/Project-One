import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'screens/garden_screen.dart';

class HabitMasteryApp extends StatelessWidget {
  const HabitMasteryApp({super.key, required this.services});

  final AppServices services;

  static ThemeData _theme(Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: brightness,
        ),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: ListenableBuilder(
        listenable: services.settings,
        builder: (context, _) => MaterialApp(
          title: 'Habit Mastery League',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          builder: (context, child) => MotionPrefs(
            reduceMotion: services.settings.reduceMotion,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const GardenScreen(),
        ),
      ),
    );
  }
}
