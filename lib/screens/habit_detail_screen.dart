import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/habit_repository.dart';
import '../data/settings_store.dart';
import '../logic/garden_guide.dart';
import '../logic/local_date.dart';
import '../logic/progress.dart';
import '../models/habit.dart';
import '../widgets/dialogs.dart';
import '../widgets/garden_guide_card.dart';
import '../widgets/plant_picture.dart';
import '../widgets/rate_bar.dart';
import 'habit_editor_screen.dart';
import 'history_screen.dart';

/// Screen 3 (detail/activity): this week's progress, the start → check in →
/// finish/reset cycle, and the Garden Guide card.
class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final int habitId;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  late final AppServices _services = AppScope.of(context);

  Habit? _habit;
  List<DateTime> _dates = const [];
  bool _loading = true;
  bool _busy = false;
  bool _guideHidden = false;
  String? _error;

  HabitRepository get _repo => _services.repository;
  SettingsStore get _settings => _services.settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final habit = await _repo.getHabit(widget.habitId);
      final dates = habit == null
          ? const <DateTime>[]
          : await _repo.getCheckInDates(widget.habitId);
      if (!mounted) return;
      setState(() {
        _habit = habit;
        _dates = dates;
        _loading = false;
        _error = habit == null ? 'This habit no longer exists.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this habit: $e';
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setStatus(CycleStatus status) async {
    await _settings.setCycleStatus(widget.habitId, status, _services.clock.today());
    if (mounted) setState(() {});
  }

  Future<void> _checkInToday() async {
    if (_busy) return;
    final today = _services.clock.today();
    final status = _settings.cycleStatus(widget.habitId, today);
    if (status == CycleStatus.finished) {
      _showMessage('This week is finished. Reset the view to keep checking in.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.addCheckIn(habitId: widget.habitId, date: today);
      if (status == CycleStatus.notStarted) await _setStatus(CycleStatus.inProgress);
      await _load();
      _showMessage('Checked in for ${formatWithWeekday(today)}.');
    } on ValidationException catch (e) {
      _showMessage(e.message);
    } on StorageException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishWeek(WeekProgress progress) async {
    await _setStatus(CycleStatus.finished);
    _showMessage('Week finished: ${progress.fullLabel}.');
  }

  Future<void> _resetWeek() async {
    final ok = await confirmAction(
      context,
      title: 'Reset this week?',
      message: 'The week goes back to "Not started". Your saved check-ins stay.',
      confirmLabel: 'Reset',
      destructive: false,
    );
    if (ok) await _setStatus(CycleStatus.notStarted);
  }

  Future<void> _openEditor({int? suggestedTarget}) async {
    final habit = _habit;
    if (habit == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HabitEditorScreen(
          existing: habit,
          suggestedTarget: suggestedTarget,
        ),
      ),
    );
    if (saved == true) {
      await _load();
      _showMessage('Habit saved.');
    }
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HistoryScreen(habitId: widget.habitId)),
    );
    await _load();
  }

  Future<void> _deleteHabit() async {
    final habit = _habit;
    if (habit == null) return;
    final count = await _repo.countCheckIns(widget.habitId);
    if (!mounted) return;
    final noun = count == 1 ? 'check-in' : 'check-ins';
    final ok = await confirmAction(
      context,
      title: 'Delete "${habit.title}"?',
      message: 'This also deletes $count $noun. This cannot be undone.',
    );
    if (!ok) return;
    try {
      await _repo.deleteHabit(widget.habitId);
      await _settings.clearCycle(widget.habitId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on StorageException catch (e) {
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = _habit;
    return Scaffold(
      appBar: AppBar(
        title: Text(habit?.title ?? 'Habit'),
        actions: [
          if (habit != null) ...[
            IconButton(
              tooltip: 'Edit habit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openEditor(),
            ),
            IconButton(
              tooltip: 'Delete habit',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteHabit,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : habit == null
              ? Center(child: Text(_error ?? 'Habit not found.'))
              : _buildContent(context, habit),
    );
  }

  Widget _buildContent(BuildContext context, Habit habit) {
    final theme = Theme.of(context);
    final today = _services.clock.today();
    final progress = weekProgress(
      checkInDates: _dates,
      target: habit.weeklyTarget,
      week: today,
    );
    final status = _settings.cycleStatus(widget.habitId, today);
    final checkedInToday = _dates.any((d) => isSameDate(d, today));
    final guide = gardenGuideFor(
      startDate: habit.startedLocalDate,
      currentTarget: habit.weeklyTarget,
      checkInDates: _dates,
      today: today,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            PlantPicture(stage: progress.stage, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.category, style: theme.textTheme.labelLarge),
                  Text(
                    'Target: ${habit.weeklyTarget} days a week · '
                    'since ${formatShort(habit.startedLocalDate)}',
                  ),
                  if (habit.motivation != null)
                    Text('"${habit.motivation}"',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('This week · ${formatWeekRange(weekStart(today))}',
                          style: theme.textTheme.titleMedium),
                    ),
                    Chip(label: Text(status.label)),
                  ],
                ),
                const SizedBox(height: 8),
                RateBar(rate: progress.cappedRate, height: 10),
                const SizedBox(height: 6),
                Text(progress.fullLabel, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  checkedInToday
                      ? 'Checked in today. One check-in per day; tapping again '
                          "won't add another."
                      : 'One check-in per day. Tapping again on the same day '
                          "won't add another.",
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (status == CycleStatus.notStarted)
                      OutlinedButton.icon(
                        onPressed: () => _setStatus(CycleStatus.inProgress),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start this week'),
                      ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _checkInToday,
                      icon: const Icon(Icons.check),
                      label: const Text('Check in today'),
                    ),
                    if (status == CycleStatus.inProgress)
                      OutlinedButton.icon(
                        onPressed: () => _finishWeek(progress),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Finish week'),
                      ),
                    if (status != CycleStatus.notStarted)
                      TextButton.icon(
                        onPressed: _resetWeek,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset view'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (!_guideHidden)
          GardenGuideCard(
            result: guide,
            onApply: (target) => _openEditor(suggestedTarget: target),
            onKeep: () => setState(() => _guideHidden = true),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _openHistory,
          icon: const Icon(Icons.history),
          label: const Text('History and check-ins'),
        ),
      ],
    );
  }
}
