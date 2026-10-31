import 'package:flutter/material.dart';

import '../logic/garden_guide.dart';

/// Shows the Garden Guide result on the Habit detail screen.
/// "Apply" opens the editor with the number filled in (nothing is saved until
/// the user presses Save). "Keep" hides the card.
class GardenGuideCard extends StatelessWidget {
  const GardenGuideCard({
    super.key,
    required this.result,
    required this.onApply,
    required this.onKeep,
  });

  final GuideResult result;
  final ValueChanged<int> onApply;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final suggested = result.suggestedTarget;
    final isError = result.status == GuideStatus.invalidInput;

    return Card(
      color: isError ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Garden Guide', style: theme.textTheme.titleMedium),
                ),
                Chip(
                  label: const Text('Rule-based helper'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: scheme.surface,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (result.hasSuggestion && suggested != null)
              Text(
                result.suggestsChange
                    ? 'Suggested weekly target: $suggested (yours is ${result.currentTarget})'
                    : 'Your target of ${result.currentTarget} matches your recent pace.',
                style: theme.textTheme.titleSmall,
              ),
            const SizedBox(height: 4),
            Text(result.message),
            const SizedBox(height: 8),
            Text(
              'Based only on your recent check-in counts. Not behavioral or '
              'health advice.',
              style: theme.textTheme.bodySmall,
            ),
            if (result.suggestsChange && suggested != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => onApply(suggested),
                    child: Text('Apply $suggested to target'),
                  ),
                  OutlinedButton(
                    onPressed: onKeep,
                    child: Text('Keep my ${result.currentTarget}'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
