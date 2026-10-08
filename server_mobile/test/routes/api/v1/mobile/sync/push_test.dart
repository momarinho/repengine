import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:server_mobile/src/services/go_core_client.dart';
import 'package:test/test.dart';

import '../../../../../../routes/api/v1/mobile/sync/push.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}
class _MockRequest extends Mock implements Request {}
class _MockGoCoreClient extends Mock implements GoCoreClient {}
class _FakeWorkoutSession extends Fake implements WorkoutSession {}
class _FakeWorkoutSetLog extends Fake implements WorkoutSetLog {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeWorkoutSession());
    registerFallbackValue(_FakeWorkoutSetLog());
  });

  group('POST /api/v1/mobile/sync/push', () {
    late _MockRequestContext context;
    late _MockRequest request;
    late _MockGoCoreClient client;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      client = _MockGoCoreClient();

      when(() => context.request).thenReturn(request);
      when(() => context.read<GoCoreClient>()).thenReturn(client);
      when(() => request.headers).thenReturn({
        'authorization': 'Bearer test-token',
      });
    });

    test('returns 405 Method Not Allowed when method is GET', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    test('processes push payload and returns SyncPushResult', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer((_) async => {
            'sessions': [
              {
                'workflow_id': 1,
                'user_id': 1,
                'section_id': 'sec_1',
                'section_title': 'Treino A',
                'status': 'active',
                'started_at': '2026-09-29T10:00:00.000Z',
                'client_id': 'client-sess-1',
              }
            ],
            'set_logs': <Map<String, dynamic>>[],
          },
        );

      when(() => client.forwardSession(any(), any())).thenAnswer(
        (_) async => const SyncPushItemStatus(
          clientId: 'client-sess-1',
          status: SyncItemStatus.accepted,
          serverId: 10,
        ),
      );

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));

      final body = await response.json() as Map<String, dynamic>;
      final result = SyncPushResult.fromJson(body);

      expect(result.items.length, equals(1));
      expect(result.items.first.clientId, equals('client-sess-1'));
      expect(result.items.first.status, equals(SyncItemStatus.accepted));
      expect(result.items.first.serverId, equals(10));
    });

    test('resolves session_id on set logs from offline session_client_id', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => request.json()).thenAnswer((_) async => {
            'sessions': [
              {
                'workflow_id': 1,
                'user_id': 1,
                'section_id': 'sec_1',
                'section_title': 'Treino A',
                'status': 'active',
                'started_at': '2026-09-29T10:00:00.000Z',
                'client_id': 'offline-sess-99',
              }
            ],
            'set_logs': [
              {
                'session_client_id': 'offline-sess-99',
                'block_client_id': 'blk_1',
                'node_type_slug': 'exercise_squat',
                'set_index': 1,
                'prescribed_reps': '5',
                'prescribed_load': '100.0',
                'actual_reps': '5',
                'actual_load': '100.0',
                'actual_rpe': '8.0',
                'completed': true,
                'client_id': 'offline-log-99',
                'created_at': '2026-09-29T10:05:00.000Z',
              }
            ],
          });

      when(() => client.forwardSession(any(), any())).thenAnswer(
        (_) async => const SyncPushItemStatus(
          clientId: 'offline-sess-99',
          status: SyncItemStatus.accepted,
          serverId: 55,
        ),
      );

      WorkoutSetLog? capturedLog;
      when(() => client.forwardSetLog(any(), any())).thenAnswer((inv) async {
        capturedLog = inv.positionalArguments[0] as WorkoutSetLog;
        return const SyncPushItemStatus(
          clientId: 'offline-log-99',
          status: SyncItemStatus.accepted,
          serverId: 101,
        );
      });

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(capturedLog, isNotNull);
      expect(capturedLog!.sessionId, equals(55));
      expect(capturedLog!.sessionClientId, equals('offline-sess-99'));

      final body = await response.json() as Map<String, dynamic>;
      final result = SyncPushResult.fromJson(body);
      expect(result.items, hasLength(2));
      expect(result.items.last.clientId, equals('offline-log-99'));
      expect(result.items.last.status, equals(SyncItemStatus.accepted));
    });
  });
}

