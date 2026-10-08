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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Set number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                '#${log.setIndex}',
                style: AppTypography.labelLarge.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Load x Reps & 1RM
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log.actualLoad} kg × ${log.actualReps} reps',
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '1RM: $estimated1RM kg',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (log.actualRpe.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• RPE ${log.actualRpe}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Completion checkmark
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0x2298BB6C),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.check,
              size: 16,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
