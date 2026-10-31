import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../logic/progress.dart';

/// Decorative plant for a habit's week. The numbers next to it are the real
/// progress; the plant is capped at "bloom" and never shows extra days.
class PlantPicture extends StatelessWidget {
  const PlantPicture({super.key, required this.stage, this.size = 40});

  final PlantStage stage;
  final double size;

  IconData get _icon => switch (stage) {
        PlantStage.seed => Icons.grain,
        PlantStage.sprout => Icons.eco,
        PlantStage.growing => Icons.grass,
        PlantStage.bloom => Icons.local_florist,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = stage == PlantStage.bloom ? scheme.tertiary : scheme.primary;
    return Container(
      width: size * 1.5,
      height: size * 1.5,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: AnimatedSwitcher(
        duration: MotionPrefs.durationOf(context),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          _icon,
          key: ValueKey(stage),
          size: size,
          color: color,
          semanticLabel: 'Plant: ${stage.label}',
        ),
      ),
    );
  }
}
