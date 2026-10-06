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
      throw ArgumentError('Lista de sessões não pode ser vazia');
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
          'Detectadas 3 falhas consecutivas em $exerciseName. '
          'Resetando ciclo em 15% (para $recLoad kg) para recuperar o sistema nervoso e reconstruir ímpeto.';
      confidence = 0.95;
    } else if (consecutiveFailures == 2) {
      recAction = AutoregulationAction.deloadIntensity;
      recLoad = _round(currentLoad * 0.90, 1);
      reasoning =
          'Detectadas 2 sessões estagnadas. Recomenda-se redução de 10% (para $recLoad kg) antes de avançar.';
      confidence = 0.85;
    } else if (consecutiveFailures == 1) {
      recAction = AutoregulationAction.maintainLoad;
      recLoad = currentLoad;
      reasoning =
          'Reps prescritas não foram alcançadas na última sessão (${lastSession.completedReps}/${lastSession.targetReps}). '
          'Mantenha a carga para uma nova tentativa.';
      confidence = 0.80;
    } else {
      if (lastRpe <= 8.5) {
        recAction = AutoregulationAction.increaseLoad;
        recLoad = _round(currentLoad + loadIncrement, 1);
        reasoning =
            'Meta alcançada com RPE submáximo ($lastRpe). '
            'Sobrecarga progressiva recomendada: +$loadIncrement kg (meta: $recLoad kg).';
        confidence = 0.90;
      } else if (lastRpe >= 9.5) {
        recAction = AutoregulationAction.maintainLoad;
        recLoad = currentLoad;
        reasoning =
            'Todas as repetições foram concluídas, mas o esforço foi no limite absoluto (RPE $lastRpe). '
            'Consolide na mesma carga antes de subir.';
        confidence = 0.85;
      } else {
        recAction = AutoregulationAction.increaseLoad;
        recLoad = _round(currentLoad + loadIncrement, 1);
        reasoning = 'Meta alcançada. Aumente a carga em +$loadIncrement kg.';
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
