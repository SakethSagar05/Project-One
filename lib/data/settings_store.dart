import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/local_date.dart';

/// Where a habit is in this week's start → track → finish cycle.
enum CycleStatus { notStarted, inProgress, finished }

extension CycleStatusLabel on CycleStatus {
  String get label => switch (this) {
        CycleStatus.notStarted => 'Not started',
        CycleStatus.inProgress => 'In progress',
        CycleStatus.finished => 'Finished',
      };
}

/// Small settings kept in SharedPreferences: the default weekly target,
/// reduce motion, and each habit's weekly cycle status. Nothing else.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _defaultTargetKey = 'defaultTarget';
  static const String _reduceMotionKey = 'reduceMotion';
  static const String _cyclePrefix = 'cycle.';
  static const int fallbackDefaultTarget = 3;

  int get defaultTarget {
    final stored = _prefs.getInt(_defaultTargetKey) ?? fallbackDefaultTarget;
    return stored.clamp(1, 7);
  }

  bool get reduceMotion => _prefs.getBool(_reduceMotionKey) ?? false;

  Future<void> setDefaultTarget(int target) async {
    if (target < 1 || target > 7) {
      throw ArgumentError.value(target, 'target', 'must be 1 to 7');
    }
    await _prefs.setInt(_defaultTargetKey, target);
    notifyListeners();
  }

  Future<void> setReduceMotion(bool value) async {
    await _prefs.setBool(_reduceMotionKey, value);
    notifyListeners();
  }

  /// Stored as "status@weekMonday", e.g. "inProgress@2026-10-26". A status
  /// from an earlier week reads as notStarted, so each week starts fresh.
  CycleStatus cycleStatus(int habitId, DateTime today) {
    final raw = _prefs.getString('$_cyclePrefix$habitId');
    if (raw == null) return CycleStatus.notStarted;
    final parts = raw.split('@');
    if (parts.length != 2 || parts[1] != toDateKey(weekStart(today))) {
      return CycleStatus.notStarted;
    }
    return CycleStatus.values.firstWhere(
      (status) => status.name == parts[0],
      orElse: () => CycleStatus.notStarted,
    );
  }

  Future<void> setCycleStatus(int habitId, CycleStatus status, DateTime today) async {
    final key = '$_cyclePrefix$habitId';
    if (status == CycleStatus.notStarted) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, '${status.name}@${toDateKey(weekStart(today))}');
    }
    notifyListeners();
  }

  /// Called when a habit is deleted.
  Future<void> clearCycle(int habitId) async {
    await _prefs.remove('$_cyclePrefix$habitId');
    notifyListeners();
  }
}
