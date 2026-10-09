import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class PlateCalculatorSheet extends StatefulWidget {
  final double initialTargetLoad;

  const PlateCalculatorSheet({super.key, required this.initialTargetLoad});

  static Future<void> show(BuildContext context, double targetLoad) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PlateCalculatorSheet(initialTargetLoad: targetLoad),
    );
  }

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  late double _targetLoad;
  double _barbellWeight = 20.0;

  static const _availablePlates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

  static final Map<double, Color> _plateColors = {
    25.0: const Color(0xFFE82424), // Red
    20.0: const Color(0xFF3B82F6), // Blue
    15.0: const Color(0xFFEAB308), // Yellow
    10.0: const Color(0xFF22C55E), // Green
    5.0: const Color(0xFFF1F5F9),  // White
    2.5: const Color(0xFF475569),  // Dark
    1.25: const Color(0xFF94A3B8), // Silver
  };

  @override
  void initState() {
    super.initState();
    _targetLoad = widget.initialTargetLoad > 0 ? widget.initialTargetLoad : 20.0;
  }

  void _adjustLoad(double delta) {
    setState(() {
      _targetLoad = (_targetLoad + delta).clamp(_barbellWeight, 500.0);
    });
  }

  Map<double, int> _calculatePlatesPerSide() {
    if (_targetLoad <= _barbellWeight) return {};

    final totalPlatesWeight = _targetLoad - _barbellWeight;
    var remaining = totalPlatesWeight / 2.0;
    final breakdown = <double, int>{};

    for (final plate in _availablePlates) {
      if (remaining >= plate) {
        final count = (remaining / plate).floor();
        if (count > 0) {
          breakdown[plate] = count;
          remaining = double.parse((remaining - (count * plate)).toStringAsFixed(2));
        }
      }
    }

    return breakdown;
  }

  String _formatWeight(double val) {
    if (val % 1 == 0) return val.toStringAsFixed(0);
    if ((val * 10) % 1 == 0) return val.toStringAsFixed(1);
    return val.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final platesPerSide = _calculatePlatesPerSide();
    final weightPerSide = _targetLoad > _barbellWeight ? (_targetLoad - _barbellWeight) / 2.0 : 0.0;
    final formattedTarget = _formatWeight(_targetLoad);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text('Plate Calculator', style: AppTypography.titleMedium),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Target Load Glanceable Hero Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                children: [
                  Text(
                    'TARGET LOAD',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$formattedTarget kg',
                        style: AppTypography.displayLarge.copyWith(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Quick adjustment steppers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildQuickStep('-5', () => _adjustLoad(-5)),
                      const SizedBox(width: 6),
                      _buildQuickStep('-2.5', () => _adjustLoad(-2.5)),
                      const SizedBox(width: 6),
                      _buildQuickStep('+2.5', () => _adjustLoad(2.5)),
                      const SizedBox(width: 6),
                      _buildQuickStep('+5', () => _adjustLoad(5)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Barbell Choice Chips
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BARBELL WEIGHT',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    _buildBarChoice(20.0, '20 kg (Olympic)'),
                    _buildBarChoice(15.0, '15 kg (Women)'),
                    _buildBarChoice(10.0, '10 kg (EZ Bar)'),
                    _buildBarChoice(0.0, '0 kg (Machine)'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Plates Per Side Result Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EACH SIDE OF BARBELL',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '${_formatWeight(weightPerSide)} kg',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (platesPerSide.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          _barbellWeight > 0
                              ? 'Empty Barbell: No plates needed on either side.'
                              : '0 kg Load: No plates needed.',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Plate Badges Wrap
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: platesPerSide.entries.map((entry) {
                        final plateWeight = entry.key;
                        final count = entry.value;
                        final color = _plateColors[plateWeight] ?? AppColors.primary;
                        final isLightColor = plateWeight == 5.0;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${count}x  ${_formatWeight(plateWeight)} kg',
                                style: TextStyle(
                                  color: isLightColor ? Colors.white : color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_barbellWeight.toStringAsFixed(0)} kg bar + 2 × (${_formatWeight(weightPerSide)} kg plates) = $formattedTarget kg',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStep(String label, VoidCallback onTap) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: const BorderSide(color: AppColors.outlineVariant),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBarChoice(double weight, String label) {
    final isSelected = _barbellWeight == weight;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _barbellWeight = weight;
          if (_targetLoad < _barbellWeight) {
            _targetLoad = _barbellWeight;
          }
        });
      },
      selectedColor: AppColors.primaryContainer,
      backgroundColor: AppColors.surfaceContainer,
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? AppColors.onBackground : AppColors.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
