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
      risk = 'Undertraining or declining workload.';
      rec = 'Gradually increase weekly volume to return to the optimal zone.';
    } else if (acwr <= 1.3) {
      zone = ACWRZone.optimal;
      risk = 'Sweet Spot: Workload is well balanced with chronic fitness.';
      rec = 'Maintain progressive linear overload.';
    } else if (acwr <= 1.5) {
      zone = ACWRZone.elevatedRisk;
      risk = 'Elevated Risk: Fatigue accumulating faster than fitness.';
      rec = 'Limit volume increases. Prioritize sleep and recovery.';
    } else {
      zone = ACWRZone.dangerZone;
      risk = 'Danger Zone (ACWR > 1.5): Excessive workload spike. High injury risk.';
      rec = 'Apply immediate deload: reduce intensity by 10% or volume by 40%.';
    }

    return ACWRResult(
      exerciseName: exerciseName,
      acuteWorkload: _round(acuteVal, 2),
      chronicWorkload: _round(chronicVal, 2),
      acwrRatio: _round(acwr, 2),
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
