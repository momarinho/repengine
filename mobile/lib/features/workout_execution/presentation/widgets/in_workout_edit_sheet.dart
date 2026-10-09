import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/routine_model.dart';

enum InWorkoutAction { swap, add }

class InWorkoutEditSheet extends StatefulWidget {
  final InWorkoutAction action;
  final RoutineExercise? currentExercise;
  final ValueChanged<RoutineExercise> onSave;
  final VoidCallback? onRemove;

  const InWorkoutEditSheet({
    super.key,
    required this.action,
    this.currentExercise,
    required this.onSave,
    this.onRemove,
  });

  static Future<void> showSwap({
    required BuildContext context,
    required RoutineExercise currentExercise,
    required ValueChanged<RoutineExercise> onSave,
    VoidCallback? onRemove,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InWorkoutEditSheet(
        action: InWorkoutAction.swap,
        currentExercise: currentExercise,
        onSave: onSave,
        onRemove: onRemove,
      ),
    );
  }

  static Future<void> showAdd({
    required BuildContext context,
    required ValueChanged<RoutineExercise> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InWorkoutEditSheet(
        action: InWorkoutAction.add,
        onSave: onSave,
      ),
    );
  }

  @override
  State<InWorkoutEditSheet> createState() => _InWorkoutEditSheetState();
}

class _InWorkoutEditSheetState extends State<InWorkoutEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _loadController;
  late final TextEditingController _restController;

  static const _popularAlternatives = [
    'Dumbbell Bench Press',
    'Incline Dumbbell Press',
    'Cable Chest Fly',
    'Barbell Back Squat',
    'Leg Press',
    'Romanian Deadlift',
    'Bulgarian Split Squat',
    'Barbell Row',
    'Dumbbell Row',
    'Lat Pulldown',
    'Seated Cable Row',
    'Overhead Press (OHP)',
    'Dumbbell Shoulder Press',
    'Lateral Raise',
    'Barbell Curl',
    'Triceps Rope Pushdown',
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.currentExercise;
    _nameController = TextEditingController(text: ex?.name ?? '');
    _setsController = TextEditingController(text: (ex?.sets ?? 3).toString());
    _repsController = TextEditingController(text: ex?.reps ?? '8');
    _loadController = TextEditingController(
      text: ex != null
          ? ex.targetLoad.toStringAsFixed(ex.targetLoad % 1 == 0 ? 0 : 1)
          : '50',
    );
    _restController = TextEditingController(text: (ex?.restSeconds ?? 90).toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _loadController.dispose();
    _restController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final sets = int.tryParse(_setsController.text.trim()) ?? 3;
    final reps = _repsController.text.trim().isEmpty ? '8' : _repsController.text.trim();
    final load = double.tryParse(_loadController.text.trim()) ?? 0.0;
    final rest = int.tryParse(_restController.text.trim()) ?? 90;

    final blockId = widget.action == InWorkoutAction.swap && widget.currentExercise != null
        ? widget.currentExercise!.blockClientId
        : 'custom_${DateTime.now().millisecondsSinceEpoch}';

    final updated = RoutineExercise(
      blockClientId: blockId,
      nodeTypeSlug: 'exercise_custom',
      name: name,
      sets: sets,
      reps: reps,
      targetLoad: load,
      restSeconds: rest,
    );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSwap = widget.action == InWorkoutAction.swap;
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: mediaQuery.viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Icon(
                  isSwap ? Icons.swap_horiz_rounded : Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSwap ? 'Swap Exercise (In-Workout)' : 'Add Exercise to Workout',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (isSwap && widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    tooltip: 'Remove from this workout',
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onRemove!();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isSwap
                  ? 'Equipment busy? Replace this exercise for today’s session.'
                  : 'Add an extra exercise or accessory to today’s session.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Quick suggestions chips
            Text(
              'QUICK SUGGESTIONS',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _popularAlternatives.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final alt = _popularAlternatives[index];
                  return ActionChip(
                    label: Text(alt),
                    backgroundColor: AppColors.surfaceContainer,
                    labelStyle: const TextStyle(fontSize: 12, color: AppColors.onSurface),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _nameController.text = alt;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Exercise Name Field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Exercise Name',
                hintText: 'e.g. Dumbbell Bench Press',
                prefixIcon: Icon(Icons.fitness_center_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Sets, Reps, Load Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _setsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sets',
                      hintText: '3',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      hintText: '8-10',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _loadController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Load (kg)',
                      hintText: '50',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Rest Time Field
            TextField(
              controller: _restController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Rest Timer (seconds)',
                hintText: '90',
                prefixIcon: Icon(Icons.timer_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 20),

            // Confirm Button
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isSwap ? 'Apply Swap to Today’s Workout' : 'Add to Today’s Workout',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
