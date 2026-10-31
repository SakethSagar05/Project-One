import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/habit_repository.dart';
import '../logic/local_date.dart';
import '../logic/progress.dart';
import '../models/check_in.dart';
import '../models/habit.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/rate_bar.dart';

/// Screen 4 (history/insights): pick a week, see its rate, and add, edit or
/// delete check-ins. Rows can be swiped away, and every row also has visible
/// Edit and Delete buttons.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.habitId});

  final int habitId;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final AppServices _services = AppScope.of(context);

  Habit? _habit;
  List<CheckIn> _checkIns = const [];
  late DateTime _week;
  bool _loading = true;
  String? _error;

  HabitRepository get _repo => _services.repository;

  @override
  void initState() {
    super.initState();
    _week = weekStart(_services.clock.today());
    _load();
  }

  Future<void> _load() async {
    try {
      final habit = await _repo.getHabit(widget.habitId);
      final checkIns = habit == null
          ? const <CheckIn>[]
          : await _repo.getCheckIns(widget.habitId);
      if (!mounted) return;
      setState(() {
        _habit = habit;
        _checkIns = checkIns;
        _loading = false;
        _error = habit == null ? 'This habit no longer exists.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load history: $e';
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _moveWeek(int weeks) => setState(() => _week = addDays(_week, 7 * weeks));

  Future<void> _addCheckIn(Habit habit) async {
    final today = _services.clock.today();
    final weekLast = addDays(_week, 6);
    final draft = await showCheckInDialog(
      context,
      title: 'Add check-in',
      initialDate: compareDates(weekLast, today) > 0 ? today : weekLast,
      firstDate: habit.startedLocalDate,
      lastDate: today,
    );
    if (draft == null) return;
    try {
      await _repo.addCheckIn(habitId: habit.id!, date: draft.date, note: draft.note);
      _showMessage('Check-in added for ${formatWithWeekday(draft.date)}.');
    } on ValidationException catch (e) {
      _showMessage(e.message);
    } on StorageException catch (e) {
      _showMessage(e.message);
    }
    await _load();
  }

  Future<void> _editCheckIn(Habit habit, CheckIn checkIn) async {
    final draft = await showCheckInDialog(
      context,
      title: 'Edit check-in',
      initialDate: checkIn.localDate,
      firstDate: habit.startedLocalDate,
      lastDate: _services.clock.today(),
      initialNote: checkIn.note ?? '',
    );
    if (draft == null) return;
    try {
      await _repo.updateCheckIn(
        CheckIn(
          id: checkIn.id,
          habitId: checkIn.habitId,
          localDate: draft.date,
          note: draft.note,
        ),
      );
      _showMessage('Check-in updated.');
    } on ValidationException catch (e) {
      _showMessage(e.message);
    } on StorageException catch (e) {
      _showMessage(e.message);
    }
    await _load();
  }

  /// Confirms, then deletes. Returns true if the row was deleted.
  Future<bool> _deleteCheckIn(CheckIn checkIn) async {
    final ok = await confirmAction(
      context,
      title: 'Delete check-in?',
      message: 'Remove the check-in for ${formatWithWeekday(checkIn.localDate)}?',
    );
    if (!ok) return false;
    try {
      await _repo.deleteCheckIn(checkIn.id!);
      _showMessage('Check-in deleted.');
      return true;
    } on StorageException catch (e) {
      _showMessage(e.message);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = _habit;
    return Scaffold(
      appBar: AppBar(title: Text(habit == null ? 'History' : '${habit.title} · History')),
      floatingActionButton: habit == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addCheckIn(habit),
              icon: const Icon(Icons.add),
              label: const Text('Add check-in'),
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
    final dates = _checkIns.map((c) => c.localDate).toList();
    final weekItems = _checkIns.where((c) => isInWeek(c.localDate, _week)).toList();
    final progress = weekProgress(
      checkInDates: dates,
      target: habit.weeklyTarget,
      week: _week,
    );
    final onTarget = weeksOnTarget(
      checkInDates: dates,
      target: habit.weeklyTarget,
      startDate: habit.startedLocalDate,
      today: today,
    );
    final canGoBack = compareDates(_week, weekStart(habit.startedLocalDate)) > 0;
    final canGoForward = compareDates(_week, weekStart(today)) < 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous week',
              icon: const Icon(Icons.chevron_left),
              onPressed: canGoBack ? () => _moveWeek(-1) : null,
            ),
            Expanded(
              child: Text(
                formatWeekRange(_week),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Next week',
              icon: const Icon(Icons.chevron_right),
              onPressed: canGoForward ? () => _moveWeek(1) : null,
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RateBar(rate: progress.cappedRate, height: 10),
                const SizedBox(height: 6),
                Text(progress.fullLabel, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('All-time check-ins: ${_checkIns.length}'),
                Text(
                  onTarget.total == 0
                      ? 'Full weeks on target: none completed yet'
                      : 'Full weeks on target: ${onTarget.met} of ${onTarget.total}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Check-ins this week', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (weekItems.isEmpty)
          const EmptyStateCard(
            icon: Icons.event_busy_outlined,
            title: 'No check-ins this week',
            message: 'Use "Add check-in" to record a day you practiced.',
          )
        else
          for (final checkIn in weekItems)
            Dismissible(
              key: ValueKey('checkin-${checkIn.id}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _deleteCheckIn(checkIn),
              onDismissed: (_) {
                setState(() {
                  _checkIns = _checkIns.where((c) => c.id != checkIn.id).toList();
                });
                _load();
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                color: theme.colorScheme.errorContainer,
                child: const Icon(Icons.delete_outline),
              ),
              child: Card(
                child: ListTile(
                  title: Text(formatWithWeekday(checkIn.localDate)),
                  subtitle: checkIn.note == null ? null : Text(checkIn.note!),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit check-in',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editCheckIn(habit, checkIn),
                      ),
                      IconButton(
                        tooltip: 'Delete check-in',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await _deleteCheckIn(checkIn)) await _load();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
