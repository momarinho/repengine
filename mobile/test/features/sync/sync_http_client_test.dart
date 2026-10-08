import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:repengine_mobile/features/sync/data/sync_http_client.dart';

void main() {
  group('SyncHttpClient Tests (Sprint 5 - Passo 1)', () {
    const testBaseUrl = 'http://localhost:8081';
    const testToken = 'test-token-jwt';

    test('pullWorkflows performs GET with auth header and query param returning SyncPullResponse', () async {
      final syncDate = DateTime.utc(2026, 10, 7, 12);
      var requestCaptured = false;

      final mockClient = MockClient((request) async {
        requestCaptured = true;
        expect(request.method, equals('GET'));
        expect(request.url.path, equals('/api/v1/mobile/sync/pull'));
        expect(request.url.queryParameters['last_synced_at'], equals(syncDate.toIso8601String()));
        expect(request.headers['authorization'], equals('Bearer $testToken'));

        final responseBody = {
          'updated_workflows': [
            {
              'id': 1,
              'user_id': 1,
              'name': 'GZCLP Hybrid',
              'description': '4-Day Linear Routine',
              'is_public': false,
              'created_at': '2026-10-01T10:00:00Z',
              'updated_at': '2026-10-07T14:00:00Z',
              'block_count': 3,
              'blocks': [],
            }
          ],
          'deleted_workflow_ids': [99],
          'server_timestamp': '2026-10-07T14:30:00Z',
        };

        return http.Response(jsonEncode(responseBody), 200);
      });

      final client = SyncHttpClient(
        client: mockClient,
        baseUrl: testBaseUrl,
        authToken: testToken,
      );

      final result = await client.pullWorkflows(lastSyncedAt: syncDate);

      expect(requestCaptured, isTrue);
      expect(result, isNotNull);
      expect(result!.updatedWorkflows, hasLength(1));
      expect(result.updatedWorkflows.first.name, equals('GZCLP Hybrid'));
      expect(result.deletedWorkflowIds, equals([99]));
    });

    test('pullWorkflows without lastSyncedAt omits query parameters', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters.containsKey('last_synced_at'), isFalse);
        return http.Response(
          jsonEncode({
            'updated_workflows': [],
            'deleted_workflow_ids': [],
            'server_timestamp': '2026-10-07T12:00:00Z',
          }),
          200,
        );
      });

      final client = SyncHttpClient(
        client: mockClient,
        baseUrl: testBaseUrl,
        authToken: testToken,
      );

      final result = await client.pullWorkflows();
      expect(result, isNotNull);
      expect(result!.updatedWorkflows, isEmpty);
    });

    test('pullWorkflows gracefully returns null when server returns 401 or error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final client = SyncHttpClient(
        client: mockClient,
        baseUrl: testBaseUrl,
        authToken: testToken,
      );

      final result = await client.pullWorkflows();
      expect(result, isNull);
    });

    test('pushMutations sends SyncPushPayload and deserializes SyncPushResult receipt', () async {
      var requestCaptured = false;

      final mockClient = MockClient((request) async {
        requestCaptured = true;
        expect(request.method, equals('POST'));
        expect(request.url.path, equals('/api/v1/mobile/sync/push'));
        expect(request.headers['authorization'], equals('Bearer $testToken'));
        expect(request.headers['content-type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['sessions'], hasLength(1));
        expect(body['set_logs'], hasLength(1));

        final responseBody = {
          'items': [
            {
              'client_id': 'sess-1',
              'status': 'accepted',
              'server_id': 10,
            },
            {
              'client_id': 'log-1',
              'status': 'accepted',
              'server_id': 100,
            }
          ],
          'processed_at': '2026-10-07T15:00:00Z',
        };

        return http.Response(jsonEncode(responseBody), 200);
      });

      final client = SyncHttpClient(
        client: mockClient,
        baseUrl: testBaseUrl,
        authToken: testToken,
      );

      final payload = SyncPushPayload(
        sessions: [
          WorkoutSession(
            clientId: 'sess-1',
            userId: 1,
            workflowId: 1,
            sectionId: 'sec_1',
            sectionTitle: 'Workout A',
            status: 'completed',
            startedAt: DateTime.utc(2026, 10, 7, 10),
            completedAt: DateTime.utc(2026, 10, 7, 11),
          ),
        ],
        setLogs: [
          WorkoutSetLog(
            clientId: 'log-1',
            sessionId: 1,
            blockClientId: 'blk_1',
            nodeTypeSlug: 'exercise_squat',
            setIndex: 1,
            prescribedReps: '5',
            prescribedLoad: '100.0',
            actualReps: '5',
            actualLoad: '100.0',
            actualRpe: '8.0',
            completed: true,
            createdAt: DateTime.utc(2026, 10, 7, 10, 5),
          ),
        ],
      );

      final result = await client.pushMutations(payload);

      expect(requestCaptured, isTrue);
      expect(result, isNotNull);
      expect(result!.items, hasLength(2));
      expect(result.items.first.status, equals(SyncItemStatus.accepted));
      expect(result.items.first.serverId, equals(10));
    });

    test('pushMutations with empty payload returns null without triggering network call', () async {
      var networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('OK', 200);
      });

      final client = SyncHttpClient(
        client: mockClient,
        baseUrl: testBaseUrl,
        authToken: testToken,
      );

      final result = await client.pushMutations(const SyncPushPayload());

      expect(result, isNull);
      expect(networkCalled, isFalse);
    });
  });
}
