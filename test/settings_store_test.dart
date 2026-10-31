import 'package:flutter_test/flutter_test.dart';
import 'package:habit_mastery_league/data/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final wednesday = DateTime(2026, 10, 28);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults: target 3, reduce motion off', () async {
    final store = SettingsStore(await SharedPreferences.getInstance());
    expect(store.defaultTarget, 3);
    expect(store.reduceMotion, isFalse);
  });

  test('settings persist in SharedPreferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs);
    await store.setDefaultTarget(5);
    await store.setReduceMotion(true);

    final reopened = SettingsStore(prefs);
    expect(reopened.defaultTarget, 5);
    expect(reopened.reduceMotion, isTrue);
  });

  test('default target outside 1..7 is refused', () async {
    final store = SettingsStore(await SharedPreferences.getInstance());
    expect(() => store.setDefaultTarget(8), throwsArgumentError);
  });

  test('cycle status is saved per habit and resets in a new week', () async {
    final store = SettingsStore(await SharedPreferences.getInstance());
    expect(store.cycleStatus(1, wednesday), CycleStatus.notStarted);

    await store.setCycleStatus(1, CycleStatus.inProgress, wednesday);
    expect(store.cycleStatus(1, wednesday), CycleStatus.inProgress);
    expect(store.cycleStatus(2, wednesday), CycleStatus.notStarted);

    await store.setCycleStatus(1, CycleStatus.finished, wednesday);
    expect(store.cycleStatus(1, DateTime(2026, 11, 1)), CycleStatus.finished); // same week
    expect(store.cycleStatus(1, DateTime(2026, 11, 2)), CycleStatus.notStarted); // next week

    await store.clearCycle(1);
    expect(store.cycleStatus(1, wednesday), CycleStatus.notStarted);
  });
}
