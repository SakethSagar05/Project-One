import 'package:flutter/material.dart';

import '../logic/local_date.dart';
import '../logic/validators.dart';

/// Yes/no confirmation. Returns true only if the user confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// What the check-in dialog returns.
class CheckInDraft {
  const CheckInDraft(this.date, this.note);
  final DateTime date;
  final String note;
}

/// Opens the add/edit check-in dialog.
Future<CheckInDraft?> showCheckInDialog(
  BuildContext context, {
  required String title,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String initialNote = '',
}) {
  return showDialog<CheckInDraft>(
    context: context,
    builder: (_) => CheckInDialog(
      title: title,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialNote: initialNote,
    ),
  );
}

class CheckInDialog extends StatefulWidget {
  const CheckInDialog({
    super.key,
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.initialNote = '',
  });

  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String initialNote;

  @override
  State<CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends State<CheckInDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _date = _clamp(widget.initialDate);
    _note = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime _clamp(DateTime date) {
    if (compareDates(date, widget.firstDate) < 0) return widget.firstDate;
    if (compareDates(date, widget.lastDate) > 0) return widget.lastDate;
    return dateOnly(date);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      helpText: 'Check-in date',
    );
    if (picked != null && mounted) setState(() => _date = dateOnly(picked));
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(CheckInDraft(_date, _note.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date', style: Theme.of(context).textTheme.labelLarge),
              Row(
                children: [
                  Expanded(child: Text(formatWithWeekday(_date))),
                  TextButton(onPressed: _pickDate, child: const Text('Change')),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLength: maxNoteLength,
                validator: validateNote,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
