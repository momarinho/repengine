import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../controller/workout_execution_controller.dart';
import '../../data/workout_repository.dart';
import '../../domain/routine_model.dart';
import '../../../../core/database/app_database.dart';

class RoutineImportSheet extends ConsumerStatefulWidget {
  const RoutineImportSheet({super.key});

  static Future<Routine?> show({
    required BuildContext context,
    required WidgetRef ref,
  }) {
    return showModalBottomSheet<Routine>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const RoutineImportSheet(),
    );
  }

  @override
  ConsumerState<RoutineImportSheet> createState() => _RoutineImportSheetState();
}

class _RoutineImportSheetState extends ConsumerState<RoutineImportSheet> {
  final TextEditingController _jsonController = TextEditingController();
  CanonicalRoutineImport? _previewRoutine;
  String? _errorMessage;
  bool _isImporting = false;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  void _validateJson(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _previewRoutine = null;
        _errorMessage = null;
      });
      return;
    }

    try {
      final parsed = CanonicalRoutineImport.parse(trimmed);
      setState(() {
        _previewRoutine = parsed;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _previewRoutine = null;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isNotEmpty) {
      _jsonController.text = text;
      _validateJson(text);
    }
  }

  Future<void> _handleImport() async {
    final routineToImport = _previewRoutine;
    if (routineToImport == null) return;

    setState(() => _isImporting = true);

    try {
      final repo = ref.read(workoutRepositoryProvider);
      final created = await repo.createRoutine(
        name: routineToImport.name,
        description: routineToImport.description,
        sections: routineToImport.sections,
      );

      // Select newly imported routine
      ref.read(selectedRoutineIdProvider.notifier).state = created.id;
      if (routineToImport.sections.isNotEmpty) {
        ref.read(selectedSectionIdProvider.notifier).state = routineToImport.sections.first.id;
      }

      if (mounted) {
        Navigator.of(context).pop(created);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Routine "${created.name}" imported successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _errorMessage = 'Failed to save routine: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final totalExercises = _previewRoutine?.sections.fold<int>(
          0,
          (sum, sec) => sum + sec.exercises.length,
        ) ??
        0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.file_download_outlined,
                      color: AppColors.tertiary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Import Routine', style: AppTypography.titleMedium),
                        Text(
                          'Paste routine JSON from Web Studio or AI prompts.',
                          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick Paste Button + Text input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Routine JSON', style: AppTypography.labelSmall),
                  TextButton.icon(
                    key: const Key('paste_clipboard_btn'),
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.paste_rounded, size: 14, color: AppColors.primary),
                    label: const Text('Paste Clipboard', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              TextField(
                key: const Key('json_input_field'),
                controller: _jsonController,
                maxLines: 4,
                minLines: 3,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: '{\n  "name": "Full Body Routine",\n  "sections": [...]\n}',
                  hintStyle: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.outline.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                onChanged: _validateJson,
              ),
              const SizedBox(height: 12),

              // Validation Error Banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Valid Routine Preview Card
              if (_previewRoutine != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _previewRoutine!.name,
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (_previewRoutine!.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _previewRoutine!.description,
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildBadge(
                            icon: Icons.calendar_today_rounded,
                            label: '${_previewRoutine!.sections.length} Days',
                          ),
                          const SizedBox(width: 8),
                          _buildBadge(
                            icon: Icons.fitness_center_rounded,
                            label: '$totalExercises Exercises',
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppColors.outlineVariant),
                      // Sections preview list
                      ...List.generate(_previewRoutine!.sections.length, (sIdx) {
                        final sec = _previewRoutine!.sections[sIdx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sec.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              ...sec.exercises.map((ex) {
                                final progLabel = ex.progressionType != null
                                    ? ' • ${ex.progressionType == 'double' ? 'Double' : '+${ex.progressionIncrement ?? 2.5}kg'}'
                                    : '';
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8, top: 2),
                                  child: Text(
                                    '• ${ex.name} (${ex.sets}x${ex.reps} @ ${ex.targetLoad}kg)$progLabel',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.outlineVariant),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('confirm_import_btn'),
                      onPressed: (_previewRoutine != null && !_isImporting) ? _handleImport : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                            )
                          : const Icon(Icons.file_download_done_rounded, size: 18),
                      label: Text(
                        _isImporting ? 'Importing...' : 'Import Routine',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.tertiary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
