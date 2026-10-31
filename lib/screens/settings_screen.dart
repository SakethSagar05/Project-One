import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/habit_repository.dart';

/// Screen 5 (settings): default weekly target, reduce motion, how weeks work,
/// and a button that adds clearly labeled fictional demo data.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppServices _services = AppScope.of(context);
  late int _defaultTarget;
  late bool _reduceMotion;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _defaultTarget = _services.settings.defaultTarget;
    _reduceMotion = _services.settings.reduceMotion;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _services.settings.setDefaultTarget(_defaultTarget);
      await _services.settings.setReduceMotion(_reduceMotion);
      _showMessage('Settings saved.');
    } catch (e) {
      _showMessage('Could not save settings: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addSample() async {
    try {
      final habit = await _services.repository.addSampleHabit();
      _showMessage('Added "${habit.title}" with fictional past check-ins.');
    } on StorageException catch (e) {
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysWord = _defaultTarget == 1 ? 'day' : 'days';
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Default weekly target for new habits: $_defaultTarget $daysWord',
              style: theme.textTheme.titleSmall),
          Slider(
            value: _defaultTarget.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            label: '$_defaultTarget',
            semanticFormatterCallback: (value) => '${value.round()} days per week',
            onChanged: (value) => setState(() => _defaultTarget = value.round()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce motion'),
            subtitle: const Text('Turn off plant and progress-bar animations'),
            value: _reduceMotion,
            onChanged: (value) => setState(() => _reduceMotion = value),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save settings'),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How weeks work', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    '• Weeks run Monday to Sunday on your device\'s local date.\n'
                    '• One check-in per habit per day. A second tap on the same '
                    'day is never counted.\n'
                    '• Weekly rate = distinct check-in days ÷ weekly target. '
                    'The plant is decoration; the numbers are the real progress.\n'
                    '• Everything stays on this device. There are no accounts '
                    'and nothing is sent online.',
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Garden Guide', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'A rule-based helper, not a trained model. It averages your '
                    'last 3 full weeks of check-ins, rounds, and keeps the '
                    'result between 1 and 7. You can apply it or keep your own '
                    'target.',
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Demo data', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Adds "Sketching (sample)" with four weeks of fictional '
                    'check-ins, so the Garden Guide card can be shown without '
                    'waiting three weeks.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addSample,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Add fictional sample habit'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
