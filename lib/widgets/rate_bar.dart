import 'package:flutter/material.dart';

import '../app_scope.dart';

/// Horizontal progress bar for a capped rate between 0 and 1.
class RateBar extends StatelessWidget {
  const RateBar({super.key, required this.rate, this.height = 8});

  final double rate;
  final double height;

  @override
  Widget build(BuildContext context) {
    final value = rate.clamp(0.0, 1.0);
    return Semantics(
      label: '${(value * 100).round()} percent of weekly target',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: MotionPrefs.durationOf(context),
            builder: (context, animated, _) => LinearProgressIndicator(
              value: animated,
              minHeight: height,
            ),
          ),
        ),
      ),
    );
  }
}
