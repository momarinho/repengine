import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/database/app_database.dart';
import '../../../../core/network/server_config.dart';
import '../../auth/data/auth_repository.dart';
import '../../workout_execution/domain/routine_model.dart';

/// Exception thrown when AI copilot routine generation fails.
class AiCopilotException implements Exception {
  final String message;

  const AiCopilotException(this.message);

  @override
  String toString() => message;
}

/// Service that coordinates with the Dart Frog BFF (via Google Genkit)
/// or directly with Google Gemini REST API (when standalone / offline from PC)
/// to generate evidence-based training routines from natural language prompts.
class AiCopilotService {
  final http.Client _client;
  final String _baseUrl;
  final String _authToken;
  final String? _defaultApiKey;

  AiCopilotService({
    http.Client? client,
    required String baseUrl,
    required this._authToken,
    this._defaultApiKey,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

  static const String _geminiSystemPrompt = '''
You are an elite sports scientist and strength & conditioning coach specializing in evidence-based periodization (hypertrophy, strength, and powerbuilding).
Design progressive overload routines that strictly follow exercise science principles:
1. Rest Intervals: Prescribe between 60 to 180 seconds of rest depending on compound vs isolation demands.
2. Volume: Keep working sets between 3 and 5 sets per exercise with safe rep targets.
3. Movement Patterns: Respect stated injury constraints and biomechanics.
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

  /// Generates a structured training routine from [prompt], supporting Bring-Your-Own-Key
  /// and automatic direct cloud fallback when the PC server is unreachable.
  Future<ParsedRoutine> generateRoutine(String prompt, {String? apiKey}) async {
    final effectiveApiKey = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : _defaultApiKey?.trim();

    // 1. First attempt: Call the RepEngine BFF (which runs Google Genkit)
    final uri = Uri.parse('$_baseUrl/api/v1/mobile/ai/generate_routine');
    final headers = <String, String>{
      'Authorization': 'Bearer $_authToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (effectiveApiKey != null && effectiveApiKey.isNotEmpty) {
      headers['x-gemini-api-key'] = effectiveApiKey;
    }

    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'prompt': prompt.trim(),
          if (effectiveApiKey != null && effectiveApiKey.isNotEmpty)
            'api_key': effectiveApiKey,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == HttpStatus.ok) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _buildParsedRoutineFromJson(data);
      } else if (response.statusCode == HttpStatus.serviceUnavailable &&
          effectiveApiKey != null &&
          effectiveApiKey.isNotEmpty) {
        // BFF has no key configured on server, but user supplied their own key: fallback to direct
        return await _generateDirectlyViaGemini(prompt, effectiveApiKey);
      } else {
        String errorMsg = 'Failed to generate routine (HTTP ${response.statusCode})';
        try {
          final errJson = jsonDecode(response.body) as Map<String, dynamic>;
          if (errJson['error'] != null) {
            errorMsg = errJson['error'].toString();
          }
        } catch (_) {}
        throw AiCopilotException(errorMsg);
      }
    } on SocketException {
      // Server is offline (e.g. gym Wi-Fi/4G away from PC)
      if (effectiveApiKey != null && effectiveApiKey.isNotEmpty) {
        return await _generateDirectlyViaGemini(prompt, effectiveApiKey);
      }
      throw const AiCopilotException(
        'Unable to connect to RepEngine server. Configure your personal Gemini API key to generate workouts anywhere.',
      );
    } on TimeoutException {
      if (effectiveApiKey != null && effectiveApiKey.isNotEmpty) {
        return await _generateDirectlyViaGemini(prompt, effectiveApiKey);
      }
      throw const AiCopilotException(
        'Server timed out. Configure your personal Gemini API key to generate workouts directly.',
      );
    } catch (e) {
      if (e is AiCopilotException) rethrow;
      if (effectiveApiKey != null && effectiveApiKey.isNotEmpty) {
        return await _generateDirectlyViaGemini(prompt, effectiveApiKey);
      }
      throw AiCopilotException('Failed to generate routine: $e');
    }
  }

  /// Direct cloud generation calling Google's Gemini endpoint directly from mobile
  /// when the athlete is away from their home PC server (BYOK standalone execution).
  Future<ParsedRoutine> _generateDirectlyViaGemini(
    String prompt,
    String apiKey,
  ) async {
    final directUri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    try {
      final directResponse = await _client.post(
        directUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': '$_geminiSystemPrompt\n\nUser Instructions: ${prompt.trim()}'
                }
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
          }
        }),
      ).timeout(const Duration(seconds: 25));

      if (directResponse.statusCode == 200) {
        final body = jsonDecode(directResponse.body) as Map<String, dynamic>;
        final candidates = body['candidates'] as List<dynamic>? ?? [];
        if (candidates.isEmpty) {
          throw const AiCopilotException('Gemini returned an empty response.');
        }

        final content = candidates[0]['content'] as Map<String, dynamic>? ?? {};
        final parts = content['parts'] as List<dynamic>? ?? [];
        if (parts.isEmpty) {
          throw const AiCopilotException('Gemini returned no content parts.');
        }

        var text = parts[0]['text']?.toString().trim() ?? '';
        if (text.startsWith('```json')) text = text.substring(7);
        if (text.startsWith('```')) text = text.substring(3);
        if (text.endsWith('```')) text = text.substring(0, text.length - 3);
        text = text.trim();

        final parsed = jsonDecode(text) as Map<String, dynamic>;
        final routineName = parsed['routine_name']?.toString() ?? 'AI Custom Routine';
        final description = parsed['description']?.toString() ?? 'Generated by RepEngine AI Copilot (Standalone)';
        final days = parsed['days'] as List<dynamic>? ?? [];

        final blocks = <Map<String, dynamic>>[];
        for (var d = 0; d < days.length; d++) {
          final day = days[d] as Map<String, dynamic>;
          final dayName = day['day_name']?.toString() ?? 'Workout Day ${d + 1}';
          blocks.add({
            'id': 'sec_${d + 1}',
            'node_type_slug': 'section',
            'data': {'title': dayName, 'subtitle': '', 'kind': 'day'},
          });

          final exercises = day['exercises'] as List<dynamic>? ?? [];
          for (var e = 0; e < exercises.length; e++) {
            final ex = exercises[e] as Map<String, dynamic>;
            final exName = ex['name']?.toString() ?? 'Exercise ${e + 1}';
            final sets = int.tryParse(ex['sets']?.toString() ?? '') ?? 3;
            final reps = ex['reps']?.toString() ?? '8';
            final load = double.tryParse(ex['target_load']?.toString() ?? '') ?? 50.0;
            final rest = int.tryParse(ex['rest_seconds']?.toString() ?? '') ?? 90;

            blocks.add({
              'id': 'blk_${d + 1}_${e + 1}',
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

        return ParsedRoutine.fromRoutine(
          Routine(
            id: 0,
            name: routineName,
            description: description,
            blockCount: blocks.length,
            isPublic: false,
            updatedAt: DateTime.now(),
            blocksJson: jsonEncode(blocks),
          ),
        );
      } else {
        throw AiCopilotException(
          'Google Gemini API error (${directResponse.statusCode}): ${directResponse.body}',
        );
      }
    } on SocketException {
      throw const AiCopilotException(
        'Unable to connect to Google Gemini. Check your mobile internet connection.',
      );
    } catch (e) {
      if (e is AiCopilotException) rethrow;
      throw AiCopilotException('Gemini direct generation error: $e');
    }
  }

  ParsedRoutine _buildParsedRoutineFromJson(Map<String, dynamic> data) {
    final routineName = data['routine_name']?.toString() ?? 'AI Custom Routine';
    final description = data['description']?.toString() ?? 'Generated by RepEngine AI Copilot';
    final blocks = data['blocks'] as List<dynamic>? ?? [];

    return ParsedRoutine.fromRoutine(
      Routine(
        id: 0,
        name: routineName,
        description: description,
        blockCount: blocks.length,
        isPublic: false,
        updatedAt: DateTime.now(),
        blocksJson: jsonEncode(blocks),
      ),
    );
  }
}

/// Global Riverpod provider for [AiCopilotService].
final aiCopilotServiceProvider = Provider<AiCopilotService>((ref) {
  final host = ref.watch(serverHostProvider);
  final authState = ref.watch(authStateProvider);
  final token = authState.token ?? 'dev-token';
  final apiKey = ref.watch(geminiApiKeyProvider);

  return AiCopilotService(
    baseUrl: host,
    authToken: token,
    defaultApiKey: apiKey.isNotEmpty ? apiKey : null,
  );
});
