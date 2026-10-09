import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/data/auth_repository.dart';
import '../../controller/workout_execution_controller.dart';
import '../../domain/routine_model.dart';

class RoutineSelectorView extends ConsumerWidget {
  final Future<void> Function({
    required int workflowId,
    required String sectionId,
    required String sectionTitle,
  }) onStartWorkout;

  const RoutineSelectorView({
    super.key,
    required this.onStartWorkout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(parsedRoutinesStreamProvider);
    final authState = ref.watch(authStateProvider);

    return routinesAsync.when(
      data: (routines) {
        if (routines.isEmpty) {
          return const Center(child: Text('No routines available.'));
        }

        final selectedRoutineId = ref.watch(selectedRoutineIdProvider) ?? routines.first.id;
        final selectedRoutine = routines.firstWhere(
          (r) => r.id == selectedRoutineId,
          orElse: () => routines.first,
        );

        final sections = selectedRoutine.sections;
        final selectedSectionId = ref.watch(selectedSectionIdProvider) ??
            (sections.isNotEmpty ? sections.first.id : null);
        final selectedSection = sections.firstWhere(
          (s) => s.id == selectedSectionId,
          orElse: () => sections.isNotEmpty ? sections.first : const RoutineSection(id: 'sec_1', title: 'Default Workout'),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: const Icon(
                        Icons.bolt,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ready to Train?', style: AppTypography.titleLarge),
                          SizedBox(height: 2),
                          Text(
                            'Select your routine and today’s workout session.',
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Web Account Connection Status Banner
              if (!authState.isAuthenticated) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Offline Mode: showing local routines. Connect your Web account in the side menu to sync your workouts.',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x1898BB6C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done_rounded, size: 18, color: AppColors.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Connected to Web account (${authState.email}) • Routines synced.',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.success,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Routine Selector (if multiple routines exist)
              if (routines.length > 1) ...[
                const Text('ROUTINE', style: AppTypography.labelSmall),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: routines.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final r = routines[index];
                      final isSelected = r.id == selectedRoutine.id;
                      return ChoiceChip(
                        label: Text(r.name),
                        selected: isSelected,
                        onSelected: (_) {
                          ref.read(selectedRoutineIdProvider.notifier).state = r.id;
                          if (r.sections.isNotEmpty) {
                            ref.read(selectedSectionIdProvider.notifier).state = r.sections.first.id;
                          }
                        },
                        selectedColor: AppColors.primaryContainer,
                        backgroundColor: AppColors.surfaceContainer,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.onBackground : AppColors.onSurfaceVariant,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Day / Section Selector
              const Text('WORKOUT DAY / SECTION', style: AppTypography.labelSmall),
              const SizedBox(height: 10),

              // Horizontal chips for day selection
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sections.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    final isSelected = section.id == selectedSection.id;

                    return GestureDetector(
                      onTap: () {
                        ref.read(selectedSectionIdProvider.notifier).state = section.id;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 16,
                              color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              section.title,
                              style: AppTypography.labelLarge.copyWith(
                                color: isSelected ? AppColors.onBackground : AppColors.onSurfaceVariant,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // Selected Section Details & Exercises
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            selectedSection.title,
                            style: AppTypography.titleMedium.copyWith(fontSize: 17),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${selectedSection.exercises.length} Exercises',
                            style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    if (selectedSection.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        selectedSection.subtitle,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const Divider(height: 20, color: AppColors.outlineVariant),

                    // Exercise list
                    if (selectedSection.exercises.isEmpty)
                      const Text(
                        'No exercises prescribed in this section.',
                        style: AppTypography.bodyMedium,
                      )
                    else
                      ...selectedSection.exercises.asMap().entries.map((entry) {
                        final i = entry.key;
                        final ex = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: AppTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onBackground,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex.name,
                                      style: AppTypography.labelLarge.copyWith(fontSize: 14),
                                    ),
                                    Text(
                                      '${ex.sets} sets × ${ex.reps} reps • ${ex.targetLoad.toStringAsFixed(0)} kg • ${ex.restSeconds}s rest',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.fitness_center_rounded,
                                size: 16,
                                color: AppColors.outline,
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Start Workout Button
              ElevatedButton.icon(
                onPressed: () => onStartWorkout(
                  workflowId: selectedRoutine.id,
                  sectionId: selectedSection.id,
                  sectionTitle: selectedSection.title,
                ),
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  selectedSection.title.toUpperCase().contains('GZCLP')
                      ? 'START WORKOUT A (GZCLP HYBRID)'
                      : 'START ${selectedSection.title.toUpperCase()}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onBackground,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}
