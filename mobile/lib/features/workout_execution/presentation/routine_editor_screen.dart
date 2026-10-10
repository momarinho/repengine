import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../controller/workout_execution_controller.dart';
import '../data/workout_repository.dart';
import '../domain/routine_model.dart';
import 'widgets/in_workout_edit_sheet.dart';

class RoutineEditorScreen extends ConsumerStatefulWidget {
  final ParsedRoutine? routineToEdit;

  const RoutineEditorScreen({super.key, this.routineToEdit});

  @override
  ConsumerState<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _EditableExercise {
  String blockClientId;
  String nodeTypeSlug;
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController loadController;
  final TextEditingController restController;

  _EditableExercise({
    required this.blockClientId,
    required this.nodeTypeSlug,
    required String name,
    required int sets,
    required String reps,
    required double targetLoad,
    required int restSeconds,
  })  : nameController = TextEditingController(text: name),
        setsController = TextEditingController(text: sets.toString()),
        repsController = TextEditingController(text: reps),
        loadController = TextEditingController(
          text: targetLoad.toStringAsFixed(targetLoad % 1 == 0 ? 0 : 1),
        ),
        restController = TextEditingController(text: restSeconds.toString());

  void dispose() {
    nameController.dispose();
    setsController.dispose();
    repsController.dispose();
    loadController.dispose();
    restController.dispose();
  }
}

class _EditableSection {
  String id;
  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final List<_EditableExercise> exercises;

  _EditableSection({
    required this.id,
    required String title,
    String subtitle = '',
    List<_EditableExercise>? exercises,
  })  : titleController = TextEditingController(text: title),
        subtitleController = TextEditingController(text: subtitle),
        exercises = exercises ?? [];

  void dispose() {
    titleController.dispose();
    subtitleController.dispose();
    for (final ex in exercises) {
      ex.dispose();
    }
  }
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final List<_EditableSection> _sections = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.routineToEdit;
    _nameController = TextEditingController(text: r?.name ?? '');
    _descController = TextEditingController(text: r?.description ?? '');

    if (r != null && r.sections.isNotEmpty) {
      for (final sec in r.sections) {
        _sections.add(_EditableSection(
          id: sec.id,
          title: sec.title,
          subtitle: sec.subtitle,
          exercises: sec.exercises
              .map((ex) => _EditableExercise(
                    blockClientId: ex.blockClientId,
                    nodeTypeSlug: ex.nodeTypeSlug,
                    name: ex.name,
                    sets: ex.sets,
                    reps: ex.reps,
                    targetLoad: ex.targetLoad,
                    restSeconds: ex.restSeconds,
                  ))
              .toList(),
        ));
      }
    } else {
      // Default initial workout day with 1 starter exercise
      _sections.add(_EditableSection(
        id: 'sec_day1',
        title: 'Workout Day 1',
        subtitle: 'Main session',
        exercises: [
          _EditableExercise(
            blockClientId: 'blk_1',
            nodeTypeSlug: 'exercise_squat',
            name: 'Barbell Back Squat',
            sets: 3,
            reps: '5',
            targetLoad: 100.0,
            restSeconds: 120,
          ),
          _EditableExercise(
            blockClientId: 'blk_2',
            nodeTypeSlug: 'exercise_bench',
            name: 'Bench Press',
            sets: 3,
            reps: '8',
            targetLoad: 75.0,
            restSeconds: 90,
          ),
        ],
      ));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    for (final sec in _sections) {
      sec.dispose();
    }
    super.dispose();
  }

  void _addSection() {
    setState(() {
      final index = _sections.length + 1;
      _sections.add(_EditableSection(
        id: 'sec_day$index',
        title: 'Workout Day $index',
        subtitle: '',
        exercises: [],
      ));
    });
  }

  void _removeSection(int index) {
    if (_sections.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A routine must contain at least one workout day.')),
      );
      return;
    }

    setState(() {
      final removed = _sections.removeAt(index);
      removed.dispose();
    });
  }

  void _addExerciseToSection(int sectionIndex) {
    InWorkoutEditSheet.showAdd(
      context: context,
      onSave: (newEx) {
        setState(() {
          _sections[sectionIndex].exercises.add(_EditableExercise(
                blockClientId: newEx.blockClientId,
                nodeTypeSlug: newEx.nodeTypeSlug,
                name: newEx.name,
                sets: newEx.sets,
                reps: newEx.reps,
                targetLoad: newEx.targetLoad,
                restSeconds: newEx.restSeconds,
              ));
        });
      },
    );
  }

  void _removeExerciseFromSection(int sectionIndex, int exerciseIndex) {
    setState(() {
      final removed = _sections[sectionIndex].exercises.removeAt(exerciseIndex);
      removed.dispose();
    });
  }

  Future<void> _handleDeleteRoutine() async {
    final r = widget.routineToEdit;
    if (r == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Delete Routine', style: AppTypography.titleMedium),
        content: Text('Are you sure you want to delete "${r.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(workoutRepositoryProvider);
      await repo.deleteRoutine(r.id);
      ref.read(selectedRoutineIdProvider.notifier).state = null;
      ref.read(selectedSectionIdProvider.notifier).state = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Routine "${r.name}" deleted.'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine name.')),
      );
      return;
    }

    final totalExercises = _sections.fold(0, (acc, s) => acc + s.exercises.length);
    if (totalExercises == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise to your routine.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(workoutRepositoryProvider);
      final finalSections = _sections.map((sec) {
        return RoutineSection(
          id: sec.id.isNotEmpty ? sec.id : 'sec_${DateTime.now().millisecondsSinceEpoch}',
          title: sec.titleController.text.trim().isNotEmpty
              ? sec.titleController.text.trim()
              : 'Workout Session',
          subtitle: sec.subtitleController.text.trim(),
          exercises: sec.exercises.map((ex) {
            final sets = int.tryParse(ex.setsController.text.trim()) ?? 3;
            final reps = ex.repsController.text.trim().isNotEmpty
                ? ex.repsController.text.trim()
                : '5';
            final load = double.tryParse(ex.loadController.text.trim()) ?? 50.0;
            final rest = int.tryParse(ex.restController.text.trim()) ?? 90;

            return RoutineExercise(
              blockClientId: ex.blockClientId.isNotEmpty
                  ? ex.blockClientId
                  : 'blk_${DateTime.now().millisecondsSinceEpoch}',
              nodeTypeSlug: ex.nodeTypeSlug.isNotEmpty ? ex.nodeTypeSlug : 'exercise_custom',
              name: ex.nameController.text.trim().isNotEmpty
                  ? ex.nameController.text.trim()
                  : 'Exercise',
              sets: sets,
              reps: reps,
              targetLoad: load,
              restSeconds: rest,
            );
          }).toList(),
        );
      }).toList();

      int savedRoutineId;
      if (widget.routineToEdit != null && widget.routineToEdit!.id > 0) {
        savedRoutineId = widget.routineToEdit!.id;
        await repo.updateRoutine(
          id: savedRoutineId,
          name: name,
          description: _descController.text.trim(),
          sections: finalSections,
        );
      } else {
        final created = await repo.createRoutine(
          name: name,
          description: _descController.text.trim(),
          sections: finalSections,
        );
        savedRoutineId = created.id;
      }

      // Automatically select this routine in the player
      ref.read(selectedRoutineIdProvider.notifier).state = savedRoutineId;
      if (finalSections.isNotEmpty) {
        ref.read(selectedSectionIdProvider.notifier).state = finalSections.first.id;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Routine "$name" saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save routine: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.routineToEdit != null && widget.routineToEdit!.id > 0;
    final isAiDraft = widget.routineToEdit != null && widget.routineToEdit!.id <= 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Edit Routine'
              : (isAiDraft ? 'AI Routine Draft' : 'Create Routine'),
          style: AppTypography.titleMedium,
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Delete Routine',
              onPressed: _handleDeleteRoutine,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                  )
                : Text(
                    isEditing ? 'Save Changes' : 'Create Routine',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Routine Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ROUTINE INFORMATION', style: AppTypography.labelSmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Routine Name',
                      hintText: 'e.g. Push Pull Legs, Upper/Lower Split',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'e.g. 4-day powerbuilding hypertrophy focus',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Workout Days / Sections Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('WORKOUT DAYS / SESSIONS', style: AppTypography.labelSmall),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Day'),
                  onPressed: _addSection,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Sections List
            ...List.generate(_sections.length, (sIndex) {
              final sec = _sections[sIndex];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sec.titleController,
                              style: AppTypography.titleMedium.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Day Title (e.g. Workout A)',
                              ),
                            ),
                          ),
                          if (_sections.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                              tooltip: 'Remove Day',
                              onPressed: () => _removeSection(sIndex),
                            ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Exercises in this day
                          if (sec.exercises.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'No exercises added yet for this day.',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                                ),
                              ),
                            ),

                          ...List.generate(sec.exercises.length, (eIndex) {
                            final ex = sec.exercises[eIndex];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ex.nameController.text,
                                          style: AppTypography.titleMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.onSurfaceVariant),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _removeExerciseFromSection(sIndex, eIndex),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Quick inline numeric adjustments
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildCompactMetricField(
                                          label: 'SETS',
                                          controller: ex.setsController,
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildCompactMetricField(
                                          label: 'REPS',
                                          controller: ex.repsController,
                                          keyboardType: TextInputType.text,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildCompactMetricField(
                                          label: 'LOAD (KG)',
                                          controller: ex.loadController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildCompactMetricField(
                                          label: 'REST (S)',
                                          controller: ex.restController,
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 4),

                          // Add Exercise Button
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Exercise'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                              foregroundColor: AppColors.primary,
                            ),
                            onPressed: () => _addExerciseToSection(sIndex),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMetricField({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(fontSize: 9, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 36,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
