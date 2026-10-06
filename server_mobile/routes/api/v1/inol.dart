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
    final rawSets = body['sets'] as List<dynamic>;

    final sets = rawSets.map((s) {
      final map = s as Map<String, dynamic>;
      return INOLSetInput(
        reps: (map['reps'] as num).toInt(),
        intensityPercentage: (map['intensity_percentage'] as num).toDouble(),
      );
    }).toList();

    final result = INOLCalculator.calculate(
      exerciseName: exerciseName,
      sets: sets,
    );

    final classificationSnakeCase = switch (result.classification) {
      INOLClassification.recovery => 'recovery',
      INOLClassification.optimal => 'optimal',
      INOLClassification.highFatigue => 'high_fatigue',
      INOLClassification.excessive => 'excessive',
    };

    return Response.json(
      body: {
        'exercise_name': result.exerciseName,
        'total_inol': result.totalInol,
        'classification': classificationSnakeCase,
        'recovery_recommendation': result.recoveryRecommendation,
      },
    );
  } catch (e) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': e.toString()},
    );
  }
}
