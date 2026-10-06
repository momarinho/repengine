import 'dart:math' as math;
import 'package:meta/meta.dart';

enum INOLClassification {
  recovery,
  optimal,
  highFatigue,
  excessive,
}

@immutable
class INOLSetInput {
  final int reps;
  final double intensityPercentage;

  const INOLSetInput({required this.reps, required this.intensityPercentage});
}

@immutable
class INOLResult {
  final String exerciseName;
  final double totalInol;
  final INOLClassification classification;
  final String recoveryRecommendation;

  const INOLResult({
    required this.exerciseName,
    required this.totalInol,
    required this.classification,
    required this.recoveryRecommendation,
  });

  Map<String, dynamic> toJson() => {
    'exercise_name': exerciseName,
    'total_inol': totalInol,
    'classification': classification.name,
    'recovery_recommendation': recoveryRecommendation,
  };
}

abstract final class INOLCalculator {
  static INOLResult calculate({
    required String exerciseName,
    required List<INOLSetInput> sets,
  }) {
    var totalInol = 0.0;

    for (final s in sets) {
      final intensity = math.min(s.intensityPercentage, 99.0);
      final denom = 100.0 - intensity;
      totalInol += s.reps / denom;
    }

    final roundedInol = _round(totalInol, 2);
    final INOLClassification classification;
    final String recomendation;

    if (roundedInol < 0.4) {
      classification = INOLClassification.recovery;
      recomendation = 'Light weight. Optimal for recovery or technique.';
    } else if (roundedInol <= 1.0) {
      classification = INOLClassification.optimal;
      recomendation = 'Ideal weight. Session with recovery in 48h.';
    } else if (roundedInol <= 1.5) {
      classification = INOLClassification.highFatigue;
      recomendation = 'High fatigue. Fatigue expected in 48-72h.';
    } else {
      classification = INOLClassification.excessive;
      recomendation = 'Excessive weight (>1.5). High risk of injury.';
    }

    return INOLResult(
      exerciseName: exerciseName,
      totalInol: roundedInol,
      classification: classification,
      recoveryRecommendation: recomendation,
    );
  }

  static double _round(double val, int places) {
    final mod = math.pow(10.0, places);
    return ((val * mod).roundToDouble()) / mod;
  }
}