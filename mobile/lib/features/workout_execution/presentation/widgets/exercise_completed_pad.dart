import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Bottom pad displayed when all prescribed sets for an exercise (or the entire routine)
/// have been completed, guiding the athlete seamlessly to the next exercise or finish summary.
class ExerciseCompletedPad extends StatelessWidget {
  final String exerciseName;
  final int completedSets;
  final int totalSets;
  final bool isAllWorkoutDone;
  final String? nextExerciseName;
  final VoidCallback? onNextExercise;
  final VoidCallback onFinishWorkout;

  const ExerciseCompletedPad({
    super.key,
    required this.exerciseName,
    required this.completedSets,
    required this.totalSets,
    required this.isAllWorkoutDone,
    this.nextExerciseName,
    this.onNextExercise,
    required this.onFinishWorkout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isAllWorkoutDone
                      ? Icons.emoji_events_rounded
                      : Icons.check_circle_rounded,
                  size: 20,
                  color: isAllWorkoutDone ? AppColors.primary : AppColors.success,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isAllWorkoutDone
                        ? 'ALL EXERCISES COMPLETED!'
                        : '${exerciseName.toUpperCase()} COMPLETED ($completedSets/$totalSets)',
                    style: AppTypography.labelLarge.copyWith(
                      color: isAllWorkoutDone ? AppColors.primary : AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isAllWorkoutDone)
              ElevatedButton.icon(
                onPressed: onFinishWorkout,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('REVIEW & FINISH WORKOUT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onBackground,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            else if (onNextExercise != null)
              ElevatedButton.icon(
                onPressed: onNextExercise,
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: Text(
                  nextExerciseName != null
                      ? 'NEXT: ${nextExerciseName!.toUpperCase()}'
                      : 'NEXT EXERCISE',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onBackground,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
