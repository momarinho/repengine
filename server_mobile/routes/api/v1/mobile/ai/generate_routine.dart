import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:server_mobile/src/services/gemini_client.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final dynamic rawBody;
  try {
    rawBody = await context.request.json();
  } catch (_) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'Invalid JSON in request body'},
    );
  }

  if (rawBody is! Map<String, dynamic>) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'Request body must be a JSON object'},
    );
  }

  final prompt = rawBody['prompt']?.toString().trim();
  if (prompt == null || prompt.isEmpty) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'Prompt must not be empty'},
    );
  }

  final goal = rawBody['goal']?.toString().trim();
  final split = rawBody['split']?.toString().trim();
  final experienceLevel = rawBody['level']?.toString().trim() ??
      rawBody['experience_level']?.toString().trim();
  final equipment = rawBody['equipment']?.toString().trim();
  final constraints = rawBody['constraints']?.toString().trim();

  Map<String, String> headers = const {};
  try {
    headers = context.request.headers;
  } catch (_) {}

  final clientApiKey = headers['x-gemini-api-key']?.trim() ??
      rawBody['api_key']?.toString().trim();

  final geminiClient = context.read<GeminiClient>();

  try {
    final generated = await geminiClient.generateRoutine(
      prompt,
      goal: goal,
      split: split,
      experienceLevel: experienceLevel,
      equipment: equipment,
      constraints: constraints,
      apiKey: clientApiKey != null && clientApiKey.isNotEmpty ? clientApiKey : null,
    );
    return Response.json(body: generated);
  } on GeminiMissingKeyException {
    return Response.json(
      statusCode: HttpStatus.serviceUnavailable,
      body: {
        'error':
            'AI routine generation is unavailable: GEMINI_API_KEY is not configured on the server.',
      },
    );
  } on GeminiApiException catch (e) {
    return Response.json(
      statusCode: HttpStatus.badGateway,
      body: {'error': 'AI provider error (${e.statusCode}): ${e.message}'},
    );
  } catch (e) {
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'error': 'Failed to generate AI routine: $e'},
    );
  }
}
