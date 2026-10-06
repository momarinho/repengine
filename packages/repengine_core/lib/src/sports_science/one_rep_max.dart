import 'dart:math' as math;
import 'package:meta/meta.dart';

@immutable
class OneRepMaxResult {
  final String exerciseName;
  final double inputLoad;
  final int inputReps;
  final double effectiveReps;
  final double brzycki1RM;
  final double epley1RM;
  final double mayhew1RM;
  final double wathen1RM;
  final double lombardi1RM;
  final double consensus1RM;
  final double stdDev;
  final (double, double) confidenceInterval95;
  final Map<int, double> repsProjection;

  const OneRepMaxResult({
    required this.exerciseName,
    required this.inputLoad,
    required this.inputReps,
    required this.effectiveReps,
    required this.brzycki1RM,
    required this.epley1RM,
    required this.mayhew1RM,
    required this.wathen1RM,
    required this.lombardi1RM,
    required this.consensus1RM,
    required this.stdDev,
    required this.confidenceInterval95,
    required this.repsProjection,
  });

  Map<String, dynamic> toJson() => {
    'exercise_name': exerciseName,
    'input_load': inputLoad,
    'input_reps': inputReps,
    'effective_reps': effectiveReps,
    'brzycki_1rm': brzycki1RM,
    'epley_1rm': epley1RM,
    'mayhew_1rm': mayhew1RM,
    'wathen_1rm': wathen1RM,
    'lombardi_1rm': lombardi1RM,
    'consensus_1rm': consensus1RM,
    'std_dev': stdDev,
    'confidence_interval_95': [
      confidenceInterval95.$1,
      confidenceInterval95.$2,
    ],
    'reps_projection': {
      for (final e in repsProjection.entries) e.key.toString(): e.value,
    },
  };
}

abstract final class OneRepMaxCalculator {
  static OneRepMaxResult calculate({
    required String exerciseName,
    required double load,
    required int reps,
    double? rpe,
    double? rir,
}) {
    // 1. Adjusted reps from RPE or RIR
    final double effectiveReps;
    if (rpe != null) {
      effectiveReps = reps + math.max(0.0, 10.0 - rpe);
    } else if (rir != null) {
      effectiveReps = reps + math.max(0.0, rir);
    } else {
      effectiveReps = reps.toDouble();
    }

    if ((effectiveReps - 1.0).abs() < 1e-3) {
      final roundedLoad = _round(load, 2);
      return OneRepMaxResult(
        exerciseName: exerciseName,
        inputLoad: roundedLoad,
        inputReps: reps,
        effectiveReps: 1.0,
        brzycki1RM: roundedLoad,
        epley1RM: roundedLoad,
        mayhew1RM: roundedLoad,
        wathen1RM: roundedLoad,
        lombardi1RM: roundedLoad,
        consensus1RM: roundedLoad,
        stdDev: 0.0,
        confidenceInterval95: (roundedLoad, roundedLoad),
        repsProjection: {
          for (int k = 1; k <= 12; k++)
            k: _round(load / (1.0 + (k-1) / 30.0), 1)
        }
      );
    }

    final r = effectiveReps;

    // 2. Canonical formulas
    final brzycki = load * (36.0 / (37.0 - math.min(r, 36.0)));
    final epley = load * (1.0 + r / 30.0);
    final mayhew = (100.0 * load) / (52.2 + 41.9 * math.exp(-0.055 * r));
    final wathen = (100.0 * load) / (48.8 + 53.8 * math.exp(-0.075 * r));
    final lombardi = load * math.pow(r, 0.10);

    final estimates = [brzycki, epley, mayhew, wathen, lombardi];
    final consensus = estimates.reduce((a, b) => a + b) / estimates.length;

    // Deviation
    final variance =
        estimates.map((x) => math.pow(x - consensus, 2)).reduce((a, b) => a + b) /
        estimates.length;
    final stdDev = math.sqrt(variance);

    // 95% CI
    final margin = 1.96 * (stdDev / math.sqrt(estimates.length));
    final ciLower = math.max(load, consensus - margin);
    final ciUpper = consensus + margin;

    final repsProjection = <int, double>{
      for (int k = 1; k <= 12; k++)
        k: _round(consensus / (1.0 + (k-1) / 30.0), 1),
    };
    repsProjection[1] = _round(consensus, 1);

    return OneRepMaxResult(
      exerciseName: exerciseName,
      inputLoad: _round(load, 2),
      inputReps: reps,
      effectiveReps: _round(effectiveReps, 2),
      brzycki1RM: _round(brzycki, 2),
      epley1RM: _round(epley, 2),
      mayhew1RM: _round(mayhew, 2),
      wathen1RM: _round(wathen, 2),
      lombardi1RM: _round(lombardi, 2),
      consensus1RM: _round(consensus, 2),
      stdDev: _round(stdDev, 2),
      confidenceInterval95: (_round(ciLower, 2), _round(ciUpper, 2)),
      repsProjection: repsProjection,
    );
  }

  static double _round(double val, int places) {
    final mod = math.pow(10.0, places);
    return ((val * mod).roundToDouble()) / mod;
  }
}
