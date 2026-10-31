import 'package:flutter/widgets.dart';

import 'data/habit_repository.dart';
import 'data/settings_store.dart';
import 'logic/local_date.dart';

/// The app's shared objects, created once in main().
class AppServices {
  AppServices({
    required this.repository,
    required this.settings,
    required this.clock,
  });

  final HabitRepository repository;
  final SettingsStore settings;
  final AppClock clock;
}

/// Makes [AppServices] available to every screen without passing it through
/// each constructor.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  /// Safe to call from initState: it does not register a rebuild dependency
  /// (the services never change while the app runs).
  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}

/// Passes the reduce-motion setting down the tree. Widgets that animate read
/// [MotionPrefs.durationOf] so animations turn off when the user asks.
class MotionPrefs extends InheritedWidget {
  const MotionPrefs({super.key, required this.reduceMotion, required super.child});

  final bool reduceMotion;

  static Duration durationOf(BuildContext context,
      [Duration normal = const Duration(milliseconds: 350)]) {
    final prefs = context.dependOnInheritedWidgetOfExactType<MotionPrefs>();
    final systemOff = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final off = (prefs?.reduceMotion ?? false) || systemOff;
    return off ? Duration.zero : normal;
  }

  @override
  bool updateShouldNotify(MotionPrefs oldWidget) =>
      reduceMotion != oldWidget.reduceMotion;
}
