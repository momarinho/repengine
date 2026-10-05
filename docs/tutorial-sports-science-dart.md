# Tutorial Prático: Ciência do Esporte em Dart Puro (`repengine_core`)

Este documento serve como o guia definitivo para implementar o módulo de **Ciência do Esporte e Análise de Performance em Dart puro** dentro de `packages/repengine_core`.

---

## 🎯 Objetivo Arquitetural
Substituir o microsserviço Python (`analytics/`) e trazer 100% da lógica matemática de hipertrofia, força e prevenção de lesões para o pacote Dart compartilhado.

**Benefícios:**
1. **Offline Imediato no Mobile**: O app Flutter calcula 1RM estimado e fadiga em microssegundos no próprio celular, sem conexão de rede.
2. **Reaproveitamento no BFF**: O Dart Frog BFF atende as requisições da Web Desktop (`/api/v1/1rm`, `/api/v1/autoregulation`, `/api/v1/acwr`) usando este mesmo código.
3. **Descomissionamento do Python**: Eliminação de ~200MB de RAM e menos complexidade de infraestrutura no Docker Compose.

---

## 🏛️ Estrutura de Arquivos a Criar

```text
packages/repengine_core/
├── lib/
│   ├── repengine_core.dart                     # Arquivo de exportação da biblioteca
│   └── src/
│       └── sports_science/
│           ├── one_rep_max.dart                # Fórmulas de 1RM (Brzycki, Epley, Mayhew, etc.)
│           ├── inol.dart                       # Intensity Number of Lifts & Fadiga
│           ├── workload_acwr.dart              # Acute:Chronic Workload Ratio & Prevenção
│           └── autoregulation.dart             # Protocolo de progressão/deload automático
└── test/
    └── sports_science_test.dart                # Bateria de testes matemáticos automatizados
```

---

## 🛠️ Passo 1: Cálculo de 1RM Multiformula (`one_rep_max.dart`)

Crie o arquivo `packages/repengine_core/lib/src/sports_science/one_rep_max.dart`:

```dart
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
    // 1. Repetições efetivas ajustadas por RPE ou RIR
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
            k: _round(load / (1.0 + (k - 1) / 30.0), 1),
        },
      );
    }

    final r = effectiveReps;

    // 2. Fórmulas canônicas
    final brzycki = load * (36.0 / (37.0 - math.min(r, 36.0)));
    final epley = load * (1.0 + r / 30.0);
    final mayhew = (100.0 * load) / (52.2 + 41.9 * math.exp(-0.055 * r));
    final wathen = (100.0 * load) / (48.8 + 53.8 * math.exp(-0.075 * r));
    final lombardi = load * math.pow(r, 0.10);

    final estimates = [brzycki, epley, mayhew, wathen, lombardi];
    final consensus = estimates.reduce((a, b) => a + b) / estimates.length;

    // Desvio padrão
    final variance =
        estimates.map((x) => math.pow(x - consensus, 2)).reduce((a, b) => a + b) /
        estimates.length;
    final stdDev = math.sqrt(variance);

    // Margem de erro 95%
    final margin = 1.96 * (stdDev / math.sqrt(estimates.length));
    final ciLower = math.max(load, consensus - margin);
    final ciUpper = consensus + margin;

    final repsProjection = <int, double>{
      for (int k = 1; k <= 12; k++)
        k: _round(consensus / (1.0 + (k - 1) / 30.0), 1),
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
```

---

## 🛠️ Passo 2: Cálculo de Fadiga e Volume Relativo (`inol.dart`)

Crie o arquivo `packages/repengine_core/lib/src/sports_science/inol.dart`:

```dart
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

  const INOLSetInput({
    required this.reps,
    required this.intensityPercentage,
  });
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
    final String recommendation;

    if (roundedInol < 0.4) {
      classification = INOLClassification.recovery;
      recommendation =
          'Estímulo leve. Excelente para dias de recuperação ou técnica.';
    } else if (roundedInol <= 1.0) {
      classification = INOLClassification.optimal;
      recommendation =
          'Estímulo ideal. Sessão produtiva com recuperação previsível em 48h.';
    } else if (roundedInol <= 1.5) {
      classification = INOLClassification.highFatigue;
      recommendation =
          'Sessão desgastante. Fadiga residual esperada por 48-72h.';
    } else {
      classification = INOLClassification.excessive;
      recommendation =
          'Estímulo excessivo (>1.5 INOL). Alto risco de estagnação e lesão.';
    }

    return INOLResult(
      exerciseName: exerciseName,
      totalInol: roundedInol,
      classification: classification,
      recoveryRecommendation: recommendation,
    );
  }

  static double _round(double val, int places) {
    final mod = math.pow(10.0, places);
    return ((val * mod).roundToDouble()) / mod;
  }
}
```

---

## 🛠️ Passo 3: Risco de Lesão Agudo/Crônico (`workload_acwr.dart`)

Crie o arquivo `packages/repengine_core/lib/src/sports_science/workload_acwr.dart`:

```dart
import 'dart:math' as math;
import 'package:meta/meta.dart';

enum ACWRZone {
  undertraining,
  optimal,
  elevatedRisk,
  dangerZone,
}

enum ACWRModel {
  coupled,
  ewma,
}

@immutable
class ACWRDay {
  final DateTime date;
  final double workload;

  const ACWRDay({
    required this.date,
    required this.workload,
  });
}

@immutable
class ACWRResult {
  final String? exerciseName;
  final double acuteWorkload;
  final double chronicWorkload;
  final double acwrRatio;
  final ACWRZone zone;
  final String riskAssessment;
  final String recommendation;

  const ACWRResult({
    this.exerciseName,
    required this.acuteWorkload,
    required this.chronicWorkload,
    required this.acwrRatio,
    required this.zone,
    required this.riskAssessment,
    required this.recommendation,
  });

  Map<String, dynamic> toJson() => {
    if (exerciseName != null) 'exercise_name': exerciseName,
    'acute_workload': acuteWorkload,
    'chronic_workload': chronicWorkload,
    'acwr_ratio': acwrRatio,
    'zone': zone.name,
    'risk_assessment': riskAssessment,
    'recommendation': recommendation,
  };
}

abstract final class ACWRCalculator {
  static ACWRResult calculate({
    String? exerciseName,
    required List<ACWRDay> history,
    int acuteDays = 7,
    int chronicDays = 28,
    ACWRModel model = ACWRModel.coupled,
  }) {
    if (history.isEmpty) {
      throw ArgumentError('Histórico de treinos não pode ser vazio');
    }

    final sorted = List<ACWRDay>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));
    final workloads = sorted.map((e) => e.workload).toList();

    final acuteN = acuteDays;
    final chronicN = math.min(chronicDays, workloads.length);

    double acuteVal;
    double chronicVal;

    if (model == ACWRModel.ewma) {
      final lambdaAcute = 2.0 / (acuteN + 1.0);
      final lambdaChronic = 2.0 / (chronicN + 1.0);

      var ewmaAcute = workloads[0];
      var ewmaChronic = workloads[0];

      for (int i = 1; i < workloads.length; i++) {
        final w = workloads[i];
        ewmaAcute = w * lambdaAcute + (1.0 - lambdaAcute) * ewmaAcute;
        ewmaChronic = w * lambdaChronic + (1.0 - lambdaChronic) * ewmaChronic;
      }

      acuteVal = ewmaAcute;
      chronicVal = math.max(1.0, ewmaChronic);
    } else {
      final acuteSlice = workloads.sublist(
        math.max(0, workloads.length - acuteN),
      );
      final chronicSlice = workloads.sublist(
        math.max(0, workloads.length - chronicN),
      );

      acuteVal = acuteSlice.reduce((a, b) => a + b) / acuteSlice.length;
      chronicVal = math.max(
        1.0,
        chronicSlice.reduce((a, b) => a + b) / chronicSlice.length,
      );
    }

    final acwr = acuteVal / chronicVal;
    final ACWRZone zone;
    final String risk;
    final String rec;

    if (acwr < 0.8) {
      zone = ACWRZone.undertraining;
      risk = 'Destreinamento ou carga em declínio.';
      rec = 'Aumente o volume semanal gradualmente para voltar à zona ideal.';
    } else if (acwr <= 1.3) {
      zone = ACWRZone.optimal;
      risk = 'Sweet Spot: Carga perfeitamente equilibrada com o preparo crônico.';
      rec = 'Mantenha a sobrecarga linear progressiva.';
    } else if (acwr <= 1.5) {
      zone = ACWRZone.elevatedRisk;
      risk = 'Risco Elevado: Fadiga acumulando mais rápido que o preparo.';
      rec = 'Limite incrementos de volume. Priorize sono e nutrição.';
    } else {
      zone = ACWRZone.dangerZone;
      risk = 'Danger Zone (ACWR > 1.5): Pico excessivo de carga. Risco iminente de lesão.';
      rec = 'Aplique deload imediato: reduza a intensidade em 10% ou o volume em 40%.';
    }

    return ACWRResult(
      exerciseName: exerciseName,
      acuteWorkload: _round(acuteVal, 2),
      chronicWorkload: _round(chronicVal, 2),
      acwr_ratio: _round(acwr, 2),
      zone: zone,
      riskAssessment: risk,
      recommendation: rec,
    );
  }

  static double _round(double val, int places) {
    final mod = math.pow(10.0, places);
    return ((val * mod).roundToDouble()) / mod;
  }
}
```

---

## 🛠️ Passo 4: Autoregulação Inteligente (`autoregulation.dart`)

Crie o arquivo `packages/repengine_core/lib/src/sports_science/autoregulation.dart`:

```dart
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
```

---

## 🛠️ Passo 5: Exportar no Pacote Compartilhado

Abra `packages/repengine_core/lib/repengine_core.dart` e adicione as 4 novas bibliotecas:

```dart
library repengine_core;

export 'src/models/workflow.dart';
export 'src/models/workout_session.dart';
export 'src/models/workout_set_log.dart';
export 'src/sync/sync_push_payload.dart';
export 'src/sync/sync_push_result.dart';
export 'src/sync/sync_pull_request.dart';
export 'src/sync/sync_pull_response.dart';

// Módulo de Ciência do Esporte & Analytics em Dart Puro
export 'src/sports_science/autoregulation.dart';
export 'src/sports_science/inol.dart';
export 'src/sports_science/one_rep_max.dart';
export 'src/sports_science/workload_acwr.dart';
```

---

## 🛠️ Passo 6: Bateria de Testes Automatizados

Crie o arquivo `packages/repengine_core/test/sports_science_test.dart`:

```dart
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
```

---

## 🧪 Como Validar

Para testar todas as fórmulas matemáticas em microssegundos:
```bash
cd packages/repengine_core
dart test
```
