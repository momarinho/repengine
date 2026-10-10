import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repengine_mobile/features/ai_copilot/data/ai_copilot_service.dart';

void main() {
  group('AiCopilotService Tests', () {
    test('generates routine and parses into unsaved draft ParsedRoutine', () async {
      final mockBffResponse = {
        'routine_name': 'Upper Lower Hypertrophy',
        'description': '4-day split for muscle hypertrophy',
        'days': [
          {'day_name': 'Day 1 - Upper'},
        ],
        'blocks': [
          {
            'id': 'sec_1',
            'node_type_slug': 'section',
            'data': {'title': 'Day 1 - Upper'},
          },
          {
            'id': 'blk_1_1',
            'node_type_slug': 'exercise_bench_press',
            'data': {
              'exercise_name': 'Barbell Bench Press',
              'sets': 4,
              'reps': '8',
              'load': 82.5,
              'rest_seconds': 120,
            },
          },
        ],
      };

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockBffResponse), 200);
      });

      final service = AiCopilotService(
        client: client,
        baseUrl: 'http://localhost:8081',
        authToken: 'test-jwt-token',
      );

      final parsed = await service.generateRoutine('4-day upper lower');

      expect(parsed.id, equals(0)); // ID 0 indicates unsaved draft
      expect(parsed.name, equals('Upper Lower Hypertrophy'));
      expect(parsed.description, equals('4-day split for muscle hypertrophy'));
      expect(parsed.sections.length, equals(1));
      expect(parsed.sections.first.title, equals('Day 1 - Upper'));
      expect(parsed.sections.first.exercises.length, equals(1));

      final exercise = parsed.sections.first.exercises.first;
      expect(exercise.name, equals('Barbell Bench Press'));
      expect(exercise.sets, equals(4));
      expect(exercise.reps, equals('8'));
      expect(exercise.targetLoad, equals(82.5));
      expect(exercise.restSeconds, equals(120));
    });

    test('throws AiCopilotException with server error message on 503', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'GEMINI_API_KEY is not configured on the server.'}),
          503,
        );
      });

      final service = AiCopilotService(
        client: client,
        baseUrl: 'http://localhost:8081',
        authToken: 'test-jwt-token',
      );

      expect(
        () => service.generateRoutine('3-day full body'),
        throwsA(
          isA<AiCopilotException>().having(
            (e) => e.message,
            'message',
            contains('GEMINI_API_KEY is not configured'),
          ),
        ),
      );
    });

    test('throws friendly message on SocketException', () async {
      final client = MockClient((request) async {
        throw const SocketException('Failed host lookup');
      });

      final service = AiCopilotService(
        client: client,
        baseUrl: 'http://localhost:8081',
        authToken: 'test-jwt-token',
      );

      expect(
        () => service.generateRoutine('Any prompt'),
        throwsA(
          isA<AiCopilotException>().having(
            (e) => e.message,
            'message',
            contains('Unable to connect to RepEngine server'),
          ),
        ),
      );
    });
  });
}
