import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/habit_repository.dart';
import '../logic/local_date.dart';
import '../logic/validators.dart';
import '../models/habit.dart';

/// Screen 2 (editor): create a new habit or edit an existing one.
/// Pops with `true` after a successful save.
class HabitEditorScreen extends StatefulWidget {
  const HabitEditorScreen({super.key, this.existing, this.suggestedTarget});

  /// Null when creating a new habit.
  final Habit? existing;

  /// Filled in when the user taps "Apply" on the Garden Guide card.
  final int? suggestedTarget;

  @override
  State<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends State<HabitEditorScreen> {
  static const List<String> _presetCategories = [
    'Study', 'Health', 'Creative', 'Mindfulness', 'Home', //
  ];

  late final AppServices _services = AppScope.of(context);
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _category;
  late final TextEditingController _motivation;
  late int _target;
  late DateTime _start;
  bool _saving = false;
  String? _formError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final habit = widget.existing;
    _title = TextEditingController(text: habit?.title ?? '');
    _category = TextEditingController(text: habit?.category ?? '');
    _motivation = TextEditingController(text: habit?.motivation ?? '');
    _target = widget.suggestedTarget ??
        habit?.weeklyTarget ??
        _services.settings.defaultTarget;
    _start = habit?.startedLocalDate ?? _services.clock.today();
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _motivation.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final today = _services.clock.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: 'Start date',
    );
    if (picked != null && mounted) setState(() => _start = dateOnly(picked));
  }

  Future<void> _save() async {
    setState(() => _formError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final draft = Habit(
      id: widget.existing?.id,
      title: _title.text,
      category: _category.text,
      weeklyTarget: _target,
      startedLocalDate: _start,
      motivation: _motivation.text,
    );
    try {
      final repo = _services.repository;
      if (_isEditing) {
        await repo.updateHabit(draft);
      } else {
        await repo.createHabit(draft);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ValidationException catch (e) {
      _showFormError(e.message);
    } on StorageException catch (e) {
      _showFormError(e.message);
    }
  }

  void _showFormError(String message) {
    if (!mounted) return;
    setState(() {
      _formError = message;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysWord = _target == 1 ? 'day' : 'days';
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit habit' : 'New habit')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.suggestedTarget != null)
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Garden Guide suggested ${widget.suggestedTarget}. It is filled '
                    'in below. Nothing is saved until you press Save.',
                  ),
                ),
              ),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Read 10 pages',
              ),
              maxLength: maxTitleLength,
              textInputAction: TextInputAction.next,
              validator: validateTitle,
            ),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'Leave empty for General',
              ),
              maxLength: maxCategoryLength,
              validator: validateCategory,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final preset in _presetCategories)
                  ActionChip(
                    label: Text(preset),
                    onPressed: () => setState(() => _category.text = preset),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Weekly target: $_target $daysWord per week',
                style: theme.textTheme.titleSmall),
            Slider(
              value: _target.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              label: '$_target',
              semanticFormatterCallback: (value) =>
                  '${value.round()} days per week',
              onChanged: (value) => setState(() => _target = value.round()),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(formatWithWeekday(_start)),
              trailing: TextButton(
                onPressed: _pickStartDate,
                child: const Text('Change'),
              ),
            ),
            TextFormField(
              controller: _motivation,
              decoration: const InputDecoration(
                labelText: 'Motivation note (optional)',
              ),
              maxLines: 3,
              maxLength: maxNoteLength,
              validator: validateNote,
            ),
            if (_formError != null) ...[
              const SizedBox(height: 8),
              Text(
                _formError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Save changes' : 'Save habit'),
            ),
          ],
        ),
      ),
    );
  }
}
