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
    final load = (body['load'] as num).toDouble();
    final reps = (body['reps'] as num).toInt();
    final rpe = (body['rpe'] as num?)?.toDouble();
    final rir = (body['rir'] as num?)?.toDouble();

    final result = OneRepMaxCalculator.calculate(
      exerciseName: exerciseName,
      load: load,
      reps: reps,
      rpe: rpe,
      rir: rir,
    );

    return Response.json(body: result.toJson());
  } catch (e) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': e.toString()},
    );
  }
}
