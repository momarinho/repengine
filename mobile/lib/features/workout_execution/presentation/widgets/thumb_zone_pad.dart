import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:repengine_core/repengine_core.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class ThumbZonePad extends StatefulWidget {
  final double initialLoad;
  final int initialReps;
  final String exerciseName;
  final double initialRpe;
  final String? progressionNote;
  final void Function(double load, int reps, double? rpe) onLogSet;

  const ThumbZonePad({
    super.key,
    this.initialLoad = 100.0,
    this.initialReps = 5,
    this.exerciseName = 'Exercício',
    this.initialRpe = 8.0,
    this.progressionNote,
    required this.onLogSet,
  });

  @override
  State<ThumbZonePad> createState() => _ThumbZonePadState();
}

class _ThumbZonePadState extends State<ThumbZonePad> {
  late double _load;
  late int _reps;
  late double _rpe;

  @override
  void initState() {
    super.initState();
    _load = widget.initialLoad;
    _reps = widget.initialReps;
    _rpe = widget.initialRpe;
  }

  @override
  void didUpdateWidget(ThumbZonePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLoad != widget.initialLoad ||
        oldWidget.initialReps != widget.initialReps) {
      _load = widget.initialLoad;
      _reps = widget.initialReps;
    }
  }

  void _adjustLoad(double delta) {
    setState(() {
      _load = (_load + delta).clamp(0.0, 999.0);
    });
    HapticFeedback.selectionClick();
  }

  void _adjustReps(int delta) {
    setState(() {
      _reps = (_reps + delta).clamp(1, 100);
    });
    HapticFeedback.selectionClick();
  }

  OneRepMaxResult get _oneRmResult {
    return OneRepMaxCalculator.calculate(
      exerciseName: widget.exerciseName,
      load: _load,
      reps: _reps,
      rpe: _rpe,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _oneRmResult;

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
            // Tag de Sobrecarga / Recomendação de Progressão
            if (widget.progressionNote != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.progressionNote!,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Pill de estimativa em tempo real com Consenso Científico de 1RM
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '1RM Consenso: ${result.consensus1RM.toStringAsFixed(1)} kg',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(±${result.stdDev.toStringAsFixed(1)} kg)',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Seletor rápido de RPE ergonômico
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'RPE: ${_rpe.toStringAsFixed(1)}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                for (final rpeValue in [7.0, 8.0, 8.5, 9.0, 10.0])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _RpeChip(
                      value: rpeValue,
                      isSelected: (_rpe - rpeValue).abs() < 0.1,
                      onTap: () {
                        setState(() => _rpe = rpeValue);
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Controles de Carga & Reps lado a lado
            Row(
              children: [
                // Seletor de Carga
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('CARGA (KG)', style: AppTypography.labelSmall),
                        const SizedBox(height: 4),
                        Text(
                          _load.toStringAsFixed(1),
                          style: AppTypography.displayLarge.copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _QuickButton(label: '-5', onTap: () => _adjustLoad(-5.0)),
                            const SizedBox(width: 4),
                            _QuickButton(label: '-2.5', onTap: () => _adjustLoad(-2.5)),
                            const SizedBox(width: 4),
                            _QuickButton(label: '+2.5', onTap: () => _adjustLoad(2.5)),
                            const SizedBox(width: 4),
                            _QuickButton(label: '+5', onTap: () => _adjustLoad(5.0)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Seletor de Repetições
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('REPETIÇÕES', style: AppTypography.labelSmall),
                        const SizedBox(height: 4),
                        Text(
                          '$_reps',
                          style: AppTypography.displayLarge.copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _QuickButton(label: '-1', onTap: () => _adjustReps(-1)),
                            const SizedBox(width: 8),
                            _QuickButton(label: '+1', onTap: () => _adjustReps(1)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Botão massivo "CONCLUIR SÉRIE"
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onLogSet(_load, _reps, _rpe);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onBackground,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'CONCLUIR SÉRIE ($_load kg × $_reps)',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.onBackground,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RpeChip extends StatelessWidget {
  final double value;
  final bool isSelected;
  final VoidCallback onTap;

  const _RpeChip({
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1),
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? AppColors.onBackground : AppColors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

