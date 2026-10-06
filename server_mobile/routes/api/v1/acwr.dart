import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:repengine_core/repengine_core.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final exerciseName = body['exercise_name'] as String?;
    final acuteDays = (body['acute_days'] as num?)?.toInt() ?? 7;
    final chronicDays = (body['chronic_days'] as num?)?.toInt() ?? 28;
    final modelStr = body['model'] as String? ?? 'coupled';
    final model = modelStr.toLowerCase() == 'ewma'
        ? ACWRModel.ewma
        : ACWRModel.coupled;

    final rawHistory = body['history'] as List<dynamic>;
    final history = rawHistory.map((h) {
      final map = h as Map<String, dynamic>;
      final dateStr = map['date'] as String;
      return ACWRDay(
        date: DateTime.parse(dateStr),
        workload: (map['workload'] as num).toDouble(),
      );
    }).toList();

    final result = ACWRCalculator.calculate(
      exerciseName: exerciseName,
      history: history,
      acuteDays: acuteDays,
      chronicDays: chronicDays,
      model: model,
    );

    // Mapeia enum camelCase para snake_case esperado pela Web
    final zoneSnakeCase = switch (result.zone) {
      ACWRZone.undertraining => 'undertraining',
      ACWRZone.optimal => 'optimal',
      ACWRZone.elevatedRisk => 'elevated_risk',
      ACWRZone.dangerZone => 'danger_zone',
    };

    return Response.json(
      body: {
        'exercise_name': result.exerciseName,
        'acute_workload': result.acuteWorkload,
        'chronic_workload': result.chronicWorkload,
        'acwr_ratio': result.acwrRatio,
        'zone': zoneSnakeCase,
        'risk_assessment': result.riskAssessment,
        'recommendation': result.recommendation,
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': e.toString()},
    );
  }
}
