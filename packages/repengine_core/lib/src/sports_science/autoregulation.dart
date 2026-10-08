import 'package:meta/meta.dart';

enum AutoregulationAction {
  increaseLoad,
  maintainLoad,
  deloadIntensity,
  resetCycle,
}

@immutable
class HistoricalSession {
  final DateTime date;
  final int targetReps;
  final int completedReps;
  final double load;
  final double? rpe;
  final bool failed;

  const HistoricalSession({
    required this.date,
    required this.targetReps,
    required this.completedReps,
    required this.load,
    this.rpe,
    this.failed = false,
  });
}

@immutable
class AutoregulationResult {
  final String exerciseName;
  final AutoregulationAction recommendedAction;
  final double currentLoad;
  final double recommendedLoad;
  final String reasoning;
  final double confidenceScore;

  const AutoregulationResult({
    required this.exerciseName,
    required this.recommendedAction,
    required this.currentLoad,
    required this.recommendedLoad,
    required this.reasoning,
    required this.confidenceScore,
  });

  Map<String, dynamic> toJson() => {
    'exercise_name': exerciseName,
    'recommended_action': recommendedAction.name,
    'current_load': currentLoad,
    'recommended_load': recommendedLoad,
    'reasoning': reasoning,
    'confidence_score': confidenceScore,
  };
}

abstract final class AutoregulationEngine {
  static AutoregulationResult evaluate({
    required String exerciseName,
    required List<HistoricalSession> sessions,
    double loadIncrement = 2.5,
  }) {
    if (sessions.isEmpty) {
      throw ArgumentError('Session list cannot be empty');
    }

    final sorted = List<HistoricalSession>.from(sessions)
      ..sort((a, b) => a.date.compareTo(b.date));
    final lastSession = sorted.last;
    final currentLoad = lastSession.load;

    var consecutiveFailures = 0;
    for (int i = sorted.length - 1; i >= 0; i--) {
      final s = sorted[i];
      if (s.failed || s.completedReps < s.targetReps) {
        consecutiveFailures++;
      } else {
        break;
      }
    }

    final lastRpe = lastSession.rpe ?? 8.0;
    final AutoregulationAction recAction;
    final double recLoad;
    final String reasoning;
    final double confidence;

    if (consecutiveFailures >= 3) {
      recAction = AutoregulationAction.resetCycle;
      recLoad = _round(currentLoad * 0.85, 1);
      reasoning =
          'Detected 3 consecutive failures in $exerciseName. '
          'Resetting cycle by 15% (to $recLoad kg) to recover nervous system and rebuild momentum.';
      confidence = 0.95;
    } else if (consecutiveFailures == 2) {
      recAction = AutoregulationAction.deloadIntensity;
      recLoad = _round(currentLoad * 0.90, 1);
      reasoning =
          'Detected 2 stagnant sessions. Recommending a 10% reduction (to $recLoad kg) before advancing.';
      confidence = 0.85;
    } else if (consecutiveFailures == 1) {
      recAction = AutoregulationAction.maintainLoad;
      recLoad = currentLoad;
      reasoning =
          'Prescribed reps were not reached in the last session (${lastSession.completedReps}/${lastSession.targetReps}). '
          'Maintain load for another attempt.';
      confidence = 0.80;
    } else {
      if (lastRpe <= 8.5) {
        recAction = AutoregulationAction.increaseLoad;
        recLoad = _round(currentLoad + loadIncrement, 1);
        reasoning =
            'Target reached with submaximal RPE ($lastRpe). '
            'Progressive overload recommended: +$loadIncrement kg (target: $recLoad kg).';
        confidence = 0.90;
      } else if (lastRpe >= 9.5) {
        recAction = AutoregulationAction.maintainLoad;
        recLoad = currentLoad;
        reasoning =
            'All reps were completed, but effort was at absolute limit (RPE $lastRpe). '
            'Consolidate at the current load before increasing.';
        confidence = 0.85;
      } else {
        recAction = AutoregulationAction.increaseLoad;
        recLoad = _round(currentLoad + loadIncrement, 1);
        reasoning = 'Target reached. Increase load by +$loadIncrement kg.';
        confidence = 0.85;
      }
    }

    return AutoregulationResult(
      exerciseName: exerciseName,
      recommendedAction: recAction,
      currentLoad: _round(currentLoad, 1),
      recommendedLoad: _round(recLoad, 1),
      reasoning: reasoning,
      confidenceScore: confidence,
    );
  }

  static double _round(double val, int places) {
    return double.parse(val.toStringAsFixed(places));
  }
}
