import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

/// Function signature for the underlying Genkit generator (allows dependency injection in tests).
typedef GenkitGeneratorFn = Future<String> Function({
  required String systemPrompt,
  required String userPrompt,
  String? apiKey,
});

/// Exception thrown when the Gemini API key is missing or blank.
class GeminiMissingKeyException implements Exception {
  const GeminiMissingKeyException();

  @override
  String toString() =>
      'GeminiMissingKeyException: GEMINI_API_KEY is not configured on the server or provided in request.';
}

/// Exception thrown when the Genkit AI provider returns an error response.
class GeminiApiException implements Exception {
  final int statusCode;
  final String message;

  const GeminiApiException(this.statusCode, this.message);

  @override
  String toString() =>
      'GeminiApiException (HTTP $statusCode): $message';
}

/// Service powered by the official Google Genkit framework to generate
/// evidence-based progressive overload routines from natural language prompts.
class GeminiClient {
  GeminiClient({
    String? apiKey,
    Genkit? genkit,
    GenkitGeneratorFn? generator,
    this.modelName = 'gemini-1.5-flash',
  })  : _apiKey = apiKey ?? Platform.environment['GEMINI_API_KEY'],
        _genkit = genkit,
        _generator = generator;

  final String? _apiKey;
  final String modelName;
  final Genkit? _genkit;
  final GenkitGeneratorFn? _generator;

  static const String _defaultSystemPrompt = '''
You are an elite sports scientist and strength & conditioning coach specializing in evidence-based periodization (hypertrophy, strength, and powerbuilding).
Design progressive overload routines that strictly follow exercise science principles:
1. Rest Intervals: Prescribe between 60 to 180 seconds of rest depending on compound vs isolation demands.
2. Volume: Keep working sets between 3 and 5 sets per exercise with safe rep targets.
3. Movement Patterns: Respect stated injury constraints and biomechanics (e.g. if shoulder discomfort is noted, replace overhead/straight bar pressing with dumbbell or neutral-grip variations).
4. Canonical Names: Use standardized English exercise names (e.g. "Barbell Back Squat", "Romanian Deadlift", "Incline Dumbbell Press").
5. Starting Loads: Provide realistic baseline loads in kilograms (kg).
6. Output Structure: Respond strictly with valid JSON conforming to:
{
  "routine_name": "Routine Title",
  "description": "Target description",
  "days": [
    {
      "day_name": "Day 1 - Push",
      "exercises": [
        {
          "name": "Barbell Bench Press",
          "sets": 4,
          "reps": "8-10",
          "target_load": 80.0,
          "rest_seconds": 120
        }
      ]
    }
  ]
}
''';

  /// Default generation implementation executing via Google Genkit framework.
  Future<String> _defaultGenkitGenerate({
    required String systemPrompt,
    required String userPrompt,
    String? apiKey,
  }) async {
    final effectiveKey = apiKey?.trim() ?? _apiKey?.trim();
    if (effectiveKey == null || effectiveKey.isEmpty) {
      throw const GeminiMissingKeyException();
    }

    final ai = _genkit ??
        Genkit(
          plugins: [googleAI(apiKey: effectiveKey)],
          isDevEnv: false,
        );

    try {
      final result = await ai.generate(
        model: googleAI.gemini(modelName),
        system: systemPrompt,
        prompt: userPrompt,
        outputFormat: 'json',
      );

      if (result.error != null) {
        throw GeminiApiException(500, result.error!.message);
      }

      final text = result.text.trim();
      if (text.isEmpty) {
        throw const GeminiApiException(500, 'Genkit returned an empty response.');
      }

      return text;
    } catch (e) {
      if (e is GeminiMissingKeyException || e is GeminiApiException) rethrow;
      throw GeminiApiException(500, 'Genkit execution failed: $e');
    }
  }

  /// Generates a structured progressive overload routine from a natural language prompt
  /// using Google Genkit, supporting optional coach architect parameters and client-provided API keys.
  Future<Map<String, dynamic>> generateRoutine(
    String prompt, {
    String? goal,
    String? split,
    String? experienceLevel,
    String? equipment,
    String? constraints,
    String? apiKey,
  }) async {
    final effectiveKey = apiKey?.trim() ?? _apiKey?.trim();
    if (_generator == null && (effectiveKey == null || effectiveKey.isEmpty)) {
      throw const GeminiMissingKeyException();
    }

    final generateFn = _generator ?? _defaultGenkitGenerate;

    final hasStructuredParams = (goal != null && goal.trim().isNotEmpty) ||
        (split != null && split.trim().isNotEmpty) ||
        (experienceLevel != null && experienceLevel.trim().isNotEmpty) ||
        (equipment != null && equipment.trim().isNotEmpty) ||
        (constraints != null && constraints.trim().isNotEmpty);

    final String finalUserPrompt;
    if (hasStructuredParams) {
      final enrichedPromptBuffer = StringBuffer();
      if (goal != null && goal.trim().isNotEmpty) {
        enrichedPromptBuffer.writeln('Primary Training Goal: ${goal.trim()}');
      }
      if (split != null && split.trim().isNotEmpty) {
        enrichedPromptBuffer.writeln('Workout Split: ${split.trim()}');
      }
      if (experienceLevel != null && experienceLevel.trim().isNotEmpty) {
        enrichedPromptBuffer.writeln('Athlete Level: ${experienceLevel.trim()}');
      }
      if (equipment != null && equipment.trim().isNotEmpty) {
        enrichedPromptBuffer.writeln('Equipment Available: ${equipment.trim()}');
      }
      if (constraints != null && constraints.trim().isNotEmpty) {
        enrichedPromptBuffer.writeln('Constraints & Injury Exclusions: ${constraints.trim()}');
      }
      enrichedPromptBuffer.writeln('Detailed Prompt / Instructions: ${prompt.trim()}');
      finalUserPrompt = enrichedPromptBuffer.toString().trim();
    } else {
      finalUserPrompt = prompt.trim();
    }

    final rawOutputText = await generateFn(
      systemPrompt: _defaultSystemPrompt,
      userPrompt: finalUserPrompt,
      apiKey: effectiveKey,
    );

    // Sanitize any potential markdown code blocks wrapping the JSON
    var cleanJson = rawOutputText.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    }
    if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    final parsedAiData = jsonDecode(cleanJson) as Map<String, dynamic>;
    final normalized = _defensivelyNormalize(parsedAiData);
    final blocks = toBlocksJson(normalized);

    return {
      'routine_name': normalized['routine_name'],
      'description': normalized['description'],
      'days': normalized['days'],
      'blocks': blocks,
    };
  }

  /// Defensively normalizes numbers and strings from AI output to prevent type casting crashes.
  Map<String, dynamic> _defensivelyNormalize(Map<String, dynamic> raw) {
    final routineName = raw['routine_name']?.toString().trim() ?? 'AI Custom Routine';
    final description = raw['description']?.toString().trim() ?? 'Generated by RepEngine AI Copilot via Genkit';
    final rawDays = raw['days'] as List<dynamic>? ?? [];

    final normalizedDays = <Map<String, dynamic>>[];

    for (var i = 0; i < rawDays.length; i++) {
      final dayMap = rawDays[i] as Map<String, dynamic>? ?? {};
      final dayName = dayMap['day_name']?.toString().trim() ?? 'Workout Day ${i + 1}';
      final rawExercises = dayMap['exercises'] as List<dynamic>? ?? [];

      final normalizedExercises = <Map<String, dynamic>>[];

      for (final ex in rawExercises) {
        final exMap = ex as Map<String, dynamic>? ?? {};
        final name = exMap['name']?.toString().trim() ?? 'Exercise';
        final sets = int.tryParse(exMap['sets']?.toString() ?? '') ?? 3;
        final reps = exMap['reps']?.toString().trim() ?? '8';
        final targetLoad = double.tryParse(exMap['target_load']?.toString() ?? '') ?? 50.0;
        final restSeconds = int.tryParse(exMap['rest_seconds']?.toString() ?? '') ?? 90;

        normalizedExercises.add({
          'name': name,
          'sets': sets,
          'reps': reps,
          'target_load': targetLoad,
          'rest_seconds': restSeconds,
        });
      }

      normalizedDays.add({
        'day_name': dayName,
        'exercises': normalizedExercises,
      });
    }

    return {
      'routine_name': routineName,
      'description': description,
      'days': normalizedDays,
    };
  }

  /// Converts normalized routine days into RepEngine's canonical `blocksJson` structure.
  List<Map<String, dynamic>> toBlocksJson(Map<String, dynamic> normalized) {
    final blocks = <Map<String, dynamic>>[];
    final days = normalized['days'] as List<dynamic>? ?? [];

    for (var d = 0; d < days.length; d++) {
      final day = days[d] as Map<String, dynamic>;
      final dayName = day['day_name'] as String;
      final exercises = day['exercises'] as List<dynamic>? ?? [];

      // Section block representing workout day
      final sectionId = 'sec_${d + 1}';
      blocks.add({
        'id': sectionId,
        'node_type_slug': 'section',
        'data': {
          'title': dayName,
          'subtitle': '',
          'kind': 'day',
        },
      });

      // Exercise blocks within the section
      for (var e = 0; e < exercises.length; e++) {
        final ex = exercises[e] as Map<String, dynamic>;
        final exName = ex['name'] as String;
        final sets = ex['sets'] as int;
        final reps = ex['reps'] as String;
        final load = ex['target_load'] as double;
        final rest = ex['rest_seconds'] as int;

        final blockId = 'blk_${d + 1}_${e + 1}';

        blocks.add({
          'id': blockId,
          'node_type_slug': 'exercise',
          'data': {
            'exercise_name': exName,
            'title': exName,
            'sets': sets,
            'reps': reps,
            'load': load,
            'load_value': load,
            'load_unit': 'kg',
            'target_load': load,
            'rest_seconds': rest,
            'notes': '',
          },
        });
      }
    }

    return blocks;
  }

  String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
