import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:server_mobile/src/services/go_core_client.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('GoCoreClient', () {
    late MockHttpClient mockHttp;
    late GoCoreClient client;

    setUp(() {
      mockHttp = MockHttpClient();
      client = GoCoreClient(baseUrl: 'http://api:8080', httpClient: mockHttp);
    });

    test(
      'forwardSession returns accepted when Go Core responds with 201',
      () async {
        when(
          () => mockHttp.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'id': 42, 'status': 'active'}),
            201,
          ),
        );

        final session = WorkoutSession(
          id: 1,
          workflowId: 10,
          userId: 1,
          sectionId: 'sec_1',
          sectionTitle: 'Chest Day',
          status: 'completed',
          startedAt: DateTime.utc(2026, 9, 27, 10),
          clientId: 'client-sess-1',
        );

        final result = await client.forwardSession(
          session,
          'Bearer test-token',
        );

        expect(result.status, equals(SyncItemStatus.accepted));
        expect(result.serverId, equals(42));
        expect(result.clientId, equals('client-sess-1'));
      },
    );

    test(
      'forwardSession returns ignoredDuplicate when Go Core responds with 409',
      () async {
        when(
          () => mockHttp.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Conflict', 409));

        final session = WorkoutSession(
          workflowId: 10,
          userId: 1,
          sectionId: 'sec_1',
          sectionTitle: 'Chest Day',
          status: 'active',
          startedAt: DateTime.utc(2026, 9, 27, 10),
          clientId: 'client-sess-dup',
        );

        final result = await client.forwardSession(
          session,
          'Bearer test-token',
        );

        expect(result.status, equals(SyncItemStatus.ignoredDuplicate));
        expect(result.clientId, equals('client-sess-dup'));
      },
    );

    test(
      'forwardSetLog returns conflictFlagged when session_id is missing',
      () async {
        final log = WorkoutSetLog(
          blockClientId: 'block_1',
          nodeTypeSlug: 'exercise_bench',
          setIndex: 0,
          clientId: 'log-no-session',
          createdAt: DateTime.utc(2026, 9, 27, 10, 5),
        );

        final result = await client.forwardSetLog(log, 'Bearer token');

        expect(result.status, equals(SyncItemStatus.conflictFlagged));
        expect(result.message, contains('Missing or invalid session_id'));
      },
    );

    test('fetchWorkflows hydrates detailed blocks from /workflows/:id', () async {
      final now = DateTime.utc(2026, 10, 1, 12);
      // List response (basic metadata without blocks)
      when(
        () => mockHttp.get(
          Uri.parse('http://api:8080/workflows?limit=100'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              {
                'id': 101,
                'user_id': 1,
                'name': 'Upper Body Hypertrophy',
                'description': 'Chest and back focus',
                'is_public': false,
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
                'block_count': 2,
              }
            ]
          }),
          200,
        ),
      );

      // Detail response (hydrated with blocks)
      when(
        () => mockHttp.get(
          Uri.parse('http://api:8080/workflows/101'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'id': 101,
            'user_id': 1,
            'name': 'Upper Body Hypertrophy',
            'description': 'Chest and back focus',
            'is_public': false,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
            'block_count': 2,
            'blocks': [
              {
                'id': 501,
                'workflow_id': 101,
                'node_type_slug': 'section',
                'position': 0,
                'data': {'title': 'Upper A', 'subtitle': 'Heavy bench and rows'}
              },
              {
                'id': 502,
                'workflow_id': 101,
                'node_type_slug': 'exercise',
                'position': 1,
                'data': {
                  'exercise_name': 'Incline Dumbbell Press',
                  'sets': 4,
                  'reps': '8-10',
                  'load': 36.0,
                  'rest_seconds': 120
                }
              }
            ]
          }),
          200,
        ),
      );

      final workflows = await client.fetchWorkflows('Bearer token');

      expect(workflows.length, equals(1));
      expect(workflows.first.id, equals(101));
      expect(workflows.first.blocks.length, equals(2));
      expect(workflows.first.blocks.first.nodeTypeSlug, equals('section'));
      expect(workflows.first.blocks.first.data['title'], equals('Upper A'));
      expect(workflows.first.blocks.last.data['exercise_name'], equals('Incline Dumbbell Press'));
    });

    test('login forwards credentials to Go Core /auth/login and returns response', () async {
      when(
        () => mockHttp.post(
          Uri.parse('http://api:8080/auth/login'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'message': 'logged in',
            'user_id': 42,
            'token': 'signed-jwt-token-42',
          }),
          200,
        ),
      );

      final result = await client.login('athlete@repengine.com', 'secret123');

      expect(result['user_id'], equals(42));
      expect(result['token'], equals('signed-jwt-token-42'));
    });

    test('login throws GoCoreAuthException on 401 unauthorized', () async {
      when(
        () => mockHttp.post(
          Uri.parse('http://api:8080/auth/login'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'error': 'invalid credentials'}),
          401,
        ),
      );

      expect(
        () => client.login('athlete@repengine.com', 'wrongpassword'),
        throwsA(isA<GoCoreAuthException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });
}
