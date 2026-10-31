import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../logic/local_date.dart';
import '../logic/progress.dart';
import '../models/habit.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/habit_tile.dart';
import '../widgets/rate_bar.dart';
import 'habit_detail_screen.dart';
import 'habit_editor_screen.dart';
import 'settings_screen.dart';

/// Screen 1 (catalog/dashboard): this week's summary, category filter and
/// one tile per habit.
class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
  late final AppServices _services = AppScope.of(context);

  bool _loading = true;
  String? _error;
  List<Habit> _habits = const [];
  List<String> _categories = const [];
  String? _category; // null = all categories
  Map<int, List<DateTime>> _weekDates = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = _services.repository;
    final today = _services.clock.today();
    try {
      final categories = await repo.getCategories();
      final category = categories.contains(_category) ? _category : null;
      final habits = await repo.getHabits(category: category);
      final weekDates =
          await repo.getCheckInDatesBetween(weekStart(today), weekEnd(today));
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _category = category;
        _habits = habits;
        _weekDates = weekDates;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your garden: $e';
      });
    }
  }

  void _selectCategory(String? category) {
    setState(() => _category = category);
    _load();
  }

  Future<void> _openNewHabit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const HabitEditorScreen()),
    );
    if (saved == true) await _load();
  }

  Future<void> _openHabit(Habit habit) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: habit.id!)),
    );
    await _load();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _load();
  }

  WeekProgress _progressFor(Habit habit, DateTime today) => weekProgress(
        checkInDates: _weekDates[habit.id] ?? const [],
        target: habit.weeklyTarget,
        week: today,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Mastery League'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewHabit,
        icon: const Icon(Icons.add),
        label: const Text('New habit'),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final today = _services.clock.today();
    final progress = {for (final h in _habits) h.id!: _progressFor(h, today)};
    final summary = gardenSummary(progress.values);
    final noHabitsAtAll = _categories.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (!noHabitsAtAll)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _category == null ? 'This week' : 'This week · $_category',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(formatWeekRange(weekStart(today)),
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  RateBar(rate: summary.rate, height: 10),
                  const SizedBox(height: 6),
                  Text(
                    '${summary.countedDays} of ${summary.totalTarget} target days '
                    '· ${summary.percent}%',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        if (_categories.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _category == null,
                onSelected: (_) => _selectCategory(null),
              ),
              for (final category in _categories)
                ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (_) => _selectCategory(category),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (noHabitsAtAll)
          EmptyStateCard(
            icon: Icons.yard_outlined,
            title: 'Your garden is empty',
            message: 'Plant your first habit and set how many days a week '
                'you want to practice it.',
            actionLabel: 'Plant a habit',
            onAction: _openNewHabit,
          )
        else if (_habits.isEmpty)
          EmptyStateCard(
            icon: Icons.filter_alt_off_outlined,
            title: 'No habits in this category',
            message: 'Choose "All" to see every habit.',
            actionLabel: 'Show all',
            onAction: () => _selectCategory(null),
          )
        else
          for (final habit in _habits)
            HabitTile(
              key: ValueKey(habit.id),
              habit: habit,
              progress: progress[habit.id]!,
              onTap: () => _openHabit(habit),
            ),
      ],
    );
  }
}
