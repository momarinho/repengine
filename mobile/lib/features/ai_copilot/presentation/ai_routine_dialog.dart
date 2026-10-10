import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/server_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../workout_execution/presentation/routine_editor_screen.dart';
import '../data/ai_copilot_service.dart';

/// Modal dialog that allows athletes to generate customized
/// progressive overload routines using natural language and BYOK.
class AiRoutineDialog extends ConsumerStatefulWidget {
  const AiRoutineDialog({super.key});

  /// Static helper to display the dialog.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AiRoutineDialog(),
    );
  }

  @override
  ConsumerState<AiRoutineDialog> createState() => _AiRoutineDialogState();
}

class _AiRoutineDialogState extends ConsumerState<AiRoutineDialog> {
  final _promptController = TextEditingController();
  late final TextEditingController _apiKeyController;
  bool _isGenerating = false;
  String? _errorMessage;
  bool _showApiKeySection = false;
  bool _hideApiKey = true;

  static const List<String> _quickSuggestions = [
    '4-Day Upper / Lower for hypertrophy',
    'Push / Pull / Legs (PPL) strength split',
    'Full Body 3x beginner compound routine',
    'Hypertrophy focus avoiding barbell squat due to knee discomfort',
  ];

  @override
  void initState() {
    super.initState();
    final savedKey = ref.read(geminiApiKeyProvider);
    _apiKeyController = TextEditingController(text: savedKey);
    _showApiKeySection = savedKey.isEmpty;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _errorMessage = 'Please describe the routine you want to create.';
      });
      return;
    }

    final keyText = _apiKeyController.text.trim();
    if (keyText.isNotEmpty) {
      await ref.read(geminiApiKeyProvider.notifier).setApiKey(keyText);
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(aiCopilotServiceProvider);
      final draftRoutine = await service.generateRoutine(
        prompt,
        apiKey: keyText.isNotEmpty ? keyText : null,
      );

      if (!mounted) return;

      // Close dialog
      Navigator.of(context).pop();

      // Navigate to RoutineEditorScreen with the generated draft
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoutineEditorScreen(
            routineToEdit: draftRoutine,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        final rawMsg = e.toString().replaceAll('AiCopilotException: ', '');
        _errorMessage = rawMsg;
        if (rawMsg.contains('API key') || rawMsg.contains('server') || rawMsg.contains('unreachable')) {
          _showApiKeySection = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeKey = ref.watch(geminiApiKeyProvider);

    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineVariant, width: 1),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'AI Routine Generator',
              style: AppTypography.titleMedium,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.vpn_key_rounded,
              size: 18,
              color: activeKey.isNotEmpty ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            tooltip: 'Configure Gemini API Key',
            onPressed: () {
              setState(() {
                _showApiKeySection = !_showApiKeySection;
              });
            },
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Describe your desired split, training frequency, or any biomechanical constraints:',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('ai_prompt_field'),
              controller: _promptController,
              enabled: !_isGenerating,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.onBackground,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 4-day Upper/Lower focused on hypertrophy, dumbbell bench press due to shoulder pain',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Quick Prompts:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.outline,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickSuggestions.map((suggestion) {
                return InkWell(
                  onTap: _isGenerating
                      ? null
                      : () {
                          setState(() {
                            _promptController.text = suggestion;
                            _errorMessage = null;
                          });
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      suggestion,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_showApiKeySection) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.key_rounded, size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Personal Gemini API Key (BYOK)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onBackground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Free key from aistudio.google.com. Generates workouts anywhere even when home PC is offline.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('ai_api_key_field'),
                      controller: _apiKeyController,
                      enabled: !_isGenerating,
                      obscureText: _hideApiKey,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onBackground,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText: 'AIzaSy...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.outlineVariant),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hideApiKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppColors.onSurfaceVariant,
                          ),
                          onPressed: () {
                            setState(() {
                              _hideApiKey = !_hideApiKey;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_isGenerating) ...[
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: const [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Designing progressive overload routine...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant)),
        ),
        ElevatedButton.icon(
          onPressed: _isGenerating ? null : _handleGenerate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.onBackground,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
          label: const Text('Generate Routine', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
