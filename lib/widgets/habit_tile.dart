import 'package:flutter/material.dart';

import '../logic/progress.dart';
import '../models/habit.dart';
import 'plant_picture.dart';
import 'rate_bar.dart';

/// One habit on the Garden screen: plant, title, numbers and a rate bar.
class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.progress,
    required this.onTap,
  });

  final Habit habit;
  final WeekProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PlantPicture(stage: progress.stage, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.title, style: theme.textTheme.titleMedium),
                    Text(habit.category, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    RateBar(rate: progress.cappedRate),
                    const SizedBox(height: 4),
                    Text(progress.fullLabel, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
