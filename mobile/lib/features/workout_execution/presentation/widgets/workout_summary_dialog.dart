import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class WorkoutSummaryDialog extends StatefulWidget {
  final WorkoutSessionData session;
  final List<WorkoutSetLogData> logs;
  final void Function({bool updateTemplate}) onConfirm;
  final VoidCallback? onAbandon;
  final bool hasModifications;

  const WorkoutSummaryDialog({
    super.key,
    required this.session,
    required this.logs,
    required this.onConfirm,
    this.onAbandon,
    this.hasModifications = true,
  });

  @override
  State<WorkoutSummaryDialog> createState() => _WorkoutSummaryDialogState();
}

class _WorkoutSummaryDialogState extends State<WorkoutSummaryDialog> {
  late bool _updateTemplate;

  @override
  void initState() {
    super.initState();
    _updateTemplate = widget.hasModifications;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final duration = now.difference(widget.session.startedAt);
    final durationStr = duration.inMinutes > 0
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : '${duration.inSeconds}s';

    double totalVolume = 0;
    int totalReps = 0;
    int completedSets = 0;

    for (final log in widget.logs) {
      if (log.completed) {
        completedSets++;
        final load = double.tryParse(log.actualLoad) ?? 0.0;
        final reps = int.tryParse(log.actualReps) ?? 0;
        totalVolume += load * reps;
        totalReps += reps;
      }
    }

    return Dialog(
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trophy / Completion Icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryContainer),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Finish Workout?',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.session.sectionTitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Metrics Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricItem(
                        label: 'TOTAL VOLUME',
                        value: '${totalVolume.toStringAsFixed(totalVolume % 1 == 0 ? 0 : 1)} kg',
                        icon: Icons.fitness_center_rounded,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.outlineVariant.withValues(alpha: 0.5),
                    ),
                    Expanded(
                      child: _MetricItem(
                        label: 'SETS / REPS',
                        value: '$completedSets / $totalReps',
                        icon: Icons.repeat_rounded,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.outlineVariant.withValues(alpha: 0.5),
                    ),
                    Expanded(
                      child: _MetricItem(
                        label: 'DURATION',
                        value: durationStr,
                        icon: Icons.timer_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Routine Template Overwrite Option
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: _updateTemplate
                      ? AppColors.primaryContainer.withValues(alpha: 0.15)
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _updateTemplate
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.outlineVariant,
                  ),
                ),
                child: InkWell(
                  onTap: () => setState(() => _updateTemplate = !_updateTemplate),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _updateTemplate,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _updateTemplate = v ?? false),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update Base Routine Template',
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Update upcoming workouts with today’s loads and swapped exercises.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Offline persistence notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done_outlined, size: 18, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saved locally in SQLite. Will sync with your account when connected.',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                        side: const BorderSide(color: AppColors.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Resume Workout'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onConfirm(updateTemplate: _updateTemplate);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Complete', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              if (widget.onAbandon != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onAbandon!();
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                    label: Text(
                      'Discard Workout',
                      style: AppTypography.labelMedium.copyWith(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
