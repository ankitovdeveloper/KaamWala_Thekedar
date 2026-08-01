import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';

/// How far the job has got, as a row of connected dots.
///
/// [JobStage] is forward-only on the server, so the timeline can treat every
/// stage up to the current one as done and never has to un-fill a step.
class StageTimeline extends StatelessWidget {
  const StageTimeline({super.key, required this.stage, this.reached = true});

  final JobStage stage;

  /// False while the request is still unanswered — the first dot is the goal,
  /// not something already achieved.
  final bool reached;

  static const _steps = [
    (JobStage.pending, 'Accept'),
    (JobStage.onTheWay, 'Raaste mein'),
    (JobStage.working, 'Kaam'),
    (JobStage.completed, 'Poora'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = reached ? JobStage.values.indexOf(stage) : -1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                // Sits level with the dot, not the label under it.
                padding: const EdgeInsets.only(top: 7),
                child: AnimatedContainer(
                  duration: Motion.normal,
                  height: 2,
                  color: i <= current ? AppColors.yellowDark : AppColors.border,
                ),
              ),
            ),
          _Step(label: _steps[i].$2, done: i <= current, active: i == current),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done, required this.active});

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: Motion.normal,
          curve: Motion.spring,
          width: active ? 16 : 12,
          height: active ? 16 : 12,
          decoration: BoxDecoration(
            color: done ? AppColors.yellow : AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? AppColors.black : AppColors.border,
              width: 2,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: AppType.nano.copyWith(
            fontSize: 10,
            color: done ? AppColors.black : AppColors.muted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
