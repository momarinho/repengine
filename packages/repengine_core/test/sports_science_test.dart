import 'package:repengine_core/repengine_core.dart';
import 'package:test/test.dart';

void main() {
  group('OneRepMaxCalculator', () {
    test('1 repetição retorna a própria carga como 1RM', () {
      final res = OneRepMaxCalculator.calculate(
        exerciseName: 'Bench Press',
        load: 100.0,
        reps: 1,
      );
      expect(res.consensus1RM, equals(100.0));
      expect(res.epley1RM, equals(100.0));
    });

    test('calcula consenso estatístico e projeções de repetição', () {
      final res = OneRepMaxCalculator.calculate(
        exerciseName: 'Squat',
        load: 100.0,
        reps: 5,
      );
      expect(res.epley1RM, closeTo(116.67, 0.1));
      expect(res.consensus1RM, greaterThan(110.0));
      expect(res.repsProjection[1], closeTo(res.consensus1RM, 0.2));
    });
  });

  group('INOLCalculator', () {
    test('calcula INOL total e recomendações de recuperação', () {
      final res = INOLCalculator.calculate(
        exerciseName: 'Deadlift',
        sets: const [
          INOLSetInput(reps: 5, intensityPercentage: 80.0),
          INOLSetInput(reps: 5, intensityPercentage: 80.0),
          INOLSetInput(reps: 5, intensityPercentage: 80.0),
        ],
      );
      expect(res.totalInol, equals(0.75));
      expect(res.classification, equals(INOLClassification.optimal));
    });
  });

  group('ACWRCalculator', () {
    test('detecta zona ótima (Sweet Spot) de carga de treino', () {
      final now = DateTime.utc(2026, 10, 4);
      final history = List.generate(
        28,
        (i) => ACWRDay(
          date: now.subtract(Duration(days: 27 - i)),
          workload: 1000.0,
        ),
      );

      final res = ACWRCalculator.calculate(history: history);
      expect(res.acwrRatio, equals(1.0));
      expect(res.zone, equals(ACWRZone.optimal));
    });
  });

  group('AutoregulationEngine', () {
    test('sugere progressão de carga quando o RPE é submáximo', () {
      final res = AutoregulationEngine.evaluate(
        exerciseName: 'Overhead Press',
        sessions: [
          HistoricalSession(
            date: DateTime.utc(2026, 10, 1),
            targetReps: 5,
            completedReps: 5,
            load: 50.0,
            rpe: 8.0,
          ),
        ],
        loadIncrement: 2.5,
      );

      expect(res.recommendedAction, equals(AutoregulationAction.increaseLoad));
      expect(res.recommendedLoad, equals(52.5));
    });

    test('aciona reset de ciclo após 3 falhas consecutivas', () {
      final res = AutoregulationEngine.evaluate(
        exerciseName: 'Squat',
        sessions: [
          HistoricalSession(
            date: DateTime.utc(2026, 10, 1),
            targetReps: 5,
            completedReps: 3,
            load: 100.0,
            failed: true,
          ),
          HistoricalSession(
            date: DateTime.utc(2026, 10, 3),
            targetReps: 5,
            completedReps: 4,
            load: 100.0,
            failed: true,
          ),
          HistoricalSession(
            date: DateTime.utc(2026, 10, 5),
            targetReps: 5,
            completedReps: 3,
            load: 100.0,
            failed: true,
          ),
        ],
      );

      expect(res.recommendedAction, equals(AutoregulationAction.resetCycle));
      expect(res.recommendedLoad, equals(85.0));
    });
  });
}
