import 'dart:convert';
import 'package:server_mobile/src/services/gemini_client.dart';
import 'package:test/test.dart';

void main() {
  group('GeminiClient with Google Genkit', () {
    test('throws GeminiMissingKeyException when apiKey is null or empty', () async {
      final unconfiguredClient = GeminiClient(
        apiKey: '',
      );

      expect(
        () => unconfiguredClient.generateRoutine('Generate workout'),
        throwsA(isA<GeminiMissingKeyException>()),
      );
    });

    test('generates routine and formats blocksJson successfully via Genkit generator', () async {
      final mockGenkitJson = jsonEncode({
        'routine_name': 'Push Pull Legs Hypertrophy',
        'description': '3-day balanced muscle building protocol',
        'days': [
          {
            'day_name': 'Day 1 - Push',
            'exercises': [
              {
                'name': 'Barbell Bench Press',
                'sets': 4,
                'reps': '8-10',
                'target_load': 80.0,
                'rest_seconds': 120,
              },
              {
                'name': 'Incline Dumbbell Press',
                'sets': 3,
                'reps': '10-12',
                'target_load': 28.0,
                'rest_seconds': 90,
              },
            ],
          },
          {
            'day_name': 'Day 2 - Pull',
            'exercises': [
              {
                'name': 'Barbell Bent Over Row',
                'sets': 4,
                'reps': '8',
                'target_load': 75.0,
                'rest_seconds': 120,
              },
            ],
          },
        ],
      });

      final client = GeminiClient(
        apiKey: 'test-genkit-key',
        generator: ({required String systemPrompt, required String userPrompt, String? apiKey}) async {
          expect(systemPrompt, contains('progressive overload'));
          expect(userPrompt, equals('Create 3-day PPL routine'));
          return '```json\n$mockGenkitJson\n```';
        },
      );

      final result = await client.generateRoutine('Create 3-day PPL routine');

      expect(result['routine_name'], equals('Push Pull Legs Hypertrophy'));
      expect(result['description'], equals('3-day balanced muscle building protocol'));

      final days = result['days'] as List<dynamic>;
      expect(days.length, equals(2));
      expect(days[0]['day_name'], equals('Day 1 - Push'));

      final blocks = result['blocks'] as List<Map<String, dynamic>>;
      expect(blocks.length, equals(5)); // 2 sections + 3 exercises

      // Verify first section
      expect(blocks[0]['node_type_slug'], equals('section'));
      expect(blocks[0]['id'], equals('sec_1'));
      expect(blocks[0]['data']['title'], equals('Day 1 - Push'));

      // Verify first exercise
      expect(blocks[1]['node_type_slug'], equals('exercise'));
      expect(blocks[1]['id'], equals('blk_1_1'));
      expect(blocks[1]['data']['exercise_name'], equals('Barbell Bench Press'));
      expect(blocks[1]['data']['sets'], equals(4));
      expect(blocks[1]['data']['reps'], equals('8-10'));
      expect(blocks[1]['data']['load'], equals(80.0));
      expect(blocks[1]['data']['load_value'], equals(80.0));
      expect(blocks[1]['data']['load_unit'], equals('kg'));
      expect(blocks[1]['data']['rest_seconds'], equals(120));

      // Verify second section
      expect(blocks[3]['node_type_slug'], equals('section'));
      expect(blocks[3]['id'], equals('sec_2'));
    });

    test('enriches user prompt with structured coach architect parameters', () async {
      final mockGenkitJson = jsonEncode({
        'routine_name': 'Upper Lower Strength',
        'days': [
          {
            'day_name': 'Day 1 - Upper',
            'exercises': [
              {
                'name': 'Dumbbell Bench Press',
                'sets': 4,
                'reps': '6-8',
                'target_load': 36.0,
                'rest_seconds': 120,
              },
            ],
          },
        ],
      });

      final client = GeminiClient(
        apiKey: 'test-genkit-key',
        generator: ({required String systemPrompt, required String userPrompt, String? apiKey}) async {
          expect(userPrompt, contains('Primary Training Goal: Hypertrophy'));
          expect(userPrompt, contains('Workout Split: 4-Day Upper/Lower'));
          expect(userPrompt, contains('Athlete Level: Intermediate'));
          expect(userPrompt, contains('Equipment Available: Dumbbells Only'));
          expect(userPrompt, contains('Constraints & Injury Exclusions: No straight barbell bench'));
          expect(userPrompt, contains('Detailed Prompt / Instructions: Emphasize chest development'));
          return mockGenkitJson;
        },
      );

      final result = await client.generateRoutine(
        'Emphasize chest development',
        goal: 'Hypertrophy',
        split: '4-Day Upper/Lower',
        experienceLevel: 'Intermediate',
        equipment: 'Dumbbells Only',
        constraints: 'No straight barbell bench',
      );

      expect(result['routine_name'], equals('Upper Lower Strength'));
      final blocks = result['blocks'] as List<Map<String, dynamic>>;
      expect(blocks.length, equals(2));
      expect(blocks[1]['node_type_slug'], equals('exercise'));
    });

    test('uses client-provided apiKey when server apiKey is not configured', () async {
      final mockGenkitJson = jsonEncode({
        'routine_name': 'Client Key Routine',
        'days': [
          {
            'day_name': 'Day 1 - Full Body',
            'exercises': [
              {
                'name': 'Kettlebell Swing',
                'sets': 5,
                'reps': '15',
                'target_load': 24.0,
                'rest_seconds': 60,
              },
            ],
          },
        ],
      });

      final clientWithoutServerKey = GeminiClient(
        apiKey: null,
        generator: ({required String systemPrompt, required String userPrompt, String? apiKey}) async {
          expect(apiKey, equals('client-provided-ai-key'));
          return mockGenkitJson;
        },
      );

      final result = await clientWithoutServerKey.generateRoutine(
        'Quick Kettlebell routine',
        apiKey: 'client-provided-ai-key',
      );

      expect(result['routine_name'], equals('Client Key Routine'));
      final blocks = result['blocks'] as List<Map<String, dynamic>>;
      expect(blocks.length, equals(2));
      expect(blocks[1]['data']['exercise_name'], equals('Kettlebell Swing'));
    });

    test('defensively handles missing or ill-typed fields in AI response', () async {
      final illTypedJson = jsonEncode({
        'routine_name': null,
        'days': [
          {
            'exercises': [
              {
                'name': null,
                'sets': '5', // string instead of int
                'target_load': '100', // string instead of double
                'rest_seconds': null,
              },
            ],
          },
        ],
      });

      final client = GeminiClient(
        apiKey: 'test-genkit-key',
        generator: ({required String systemPrompt, required String userPrompt, String? apiKey}) async {
          return illTypedJson;
        },
      );

      final result = await client.generateRoutine('Minimal prompt');

      expect(result['routine_name'], equals('AI Custom Routine'));
      final blocks = result['blocks'] as List<Map<String, dynamic>>;
      expect(blocks.length, equals(2)); // 1 section + 1 exercise
      expect(blocks[1]['data']['sets'], equals(5));
      expect(blocks[1]['data']['load'], equals(100.0));
      expect(blocks[1]['data']['rest_seconds'], equals(90)); // default fallback
    });

    test('throws GeminiApiException on Genkit generator failure', () async {
      final client = GeminiClient(
        apiKey: 'test-genkit-key',
        generator: ({required String systemPrompt, required String userPrompt, String? apiKey}) async {
          throw const GeminiApiException(500, 'Genkit model error');
        },
      );

      expect(
        () => client.generateRoutine('Heavy Squat Routine'),
        throwsA(
          isA<GeminiApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            equals(500),
          ),
        ),
      );
    });
  });
}
