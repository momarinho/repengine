import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:repengine_core/repengine_core.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final exerciseName = body['exercise_name'] as String? ?? 'Exercise';
    final loadIncrement =
        (body['load_increment'] as num?)?.toDouble() ?? 2.5;
    final rawSessions = body['sessions'] as List<dynamic>;

    final sessions = rawSessions.map((s) {
      final map = s as Map<String, dynamic>;
      final dateStr = map['date'] as String;
      return HistoricalSession(
        date: DateTime.parse(dateStr),
        targetReps: (map['target_reps'] as num).toInt(),
        completedReps: (map['completed_reps'] as num).toInt(),
        load: (map['load'] as num).toDouble(),
        rpe: (map['rpe'] as num?)?.toDouble(),
        failed: map['failed'] as bool? ?? false,
      );
    }).toList();

    final result = AutoregulationEngine.evaluate(
      exerciseName: exerciseName,
      sessions: sessions,
      loadIncrement: loadIncrement,
    );

    // Mapeia enum camelCase para snake_case esperado pela Web
    final actionSnakeCase = switch (result.recommendedAction) {
      AutoregulationAction.increaseLoad => 'increase_load',
      AutoregulationAction.maintainLoad => 'maintain_load',
      AutoregulationAction.deloadIntensity => 'deload_intensity',
      AutoregulationAction.resetCycle => 'reset_cycle',
    };

    return Response.json(
      body: {
        'exercise_name': result.exerciseName,
        'recommended_action': actionSnakeCase,
        'current_load': result.currentLoad,
        'recommended_load': result.recommendedLoad,
        'reasoning': result.reasoning,
        'confidence_score': result.confidenceScore,
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': e.toString()},
    );
  }
}
