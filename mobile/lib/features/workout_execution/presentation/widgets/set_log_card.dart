import 'package:flutter/material.dart';
import 'package:repengine_core/repengine_core.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class SetLogCard extends StatelessWidget {
  final WorkoutSetLogData log;

  const SetLogCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    // Statistical Consensus 1RM Calculation (repengine_core)
    final actualLoadNum = double.tryParse(log.actualLoad) ?? 0.0;
    final actualRepsNum = int.tryParse(log.actualReps) ?? 0;
    final actualRpeNum = double.tryParse(log.actualRpe);

    final oneRmResult = (actualLoadNum > 0 && actualRepsNum > 0)
        ? OneRepMaxCalculator.calculate(
            exerciseName: log.nodeTypeSlug,
            load: actualLoadNum,
            reps: actualRepsNum,
            rpe: actualRpeNum,
          )
        : null;

    final estimated1RM = oneRmResult != null
        ? oneRmResult.consensus1RM.toStringAsFixed(1)
        : actualLoadNum.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          // Set number
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#${log.setIndex}',
                style: AppTypography.labelLarge.copyWith(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Load x Reps & 1RM
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log.actualLoad} kg × ${log.actualReps} reps',
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '1RM: $estimated1RM kg',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    if (log.actualRpe.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• RPE ${log.actualRpe}',
                        style: AppTypography.labelSmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Completion checkmark
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0x2298BB6C),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 20,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
