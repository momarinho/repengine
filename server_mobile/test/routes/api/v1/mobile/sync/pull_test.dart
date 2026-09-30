import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:server_mobile/src/services/go_core_client.dart';
import 'package:test/test.dart';

import '../../../../../../routes/api/v1/mobile/sync/pull.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

class _MockGoCoreClient extends Mock implements GoCoreClient {}

void main() {
  group('GET /api/v1/mobile/sync/pull', () {
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

    test('returns 405 Method Not Allowed when method is POST', () async {
      when(() => request.method).thenReturn(HttpMethod.post);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    test(
      'returns all active workflows on initial sync (no last_synced_at)',
      () async {
        when(() => request.method).thenReturn(HttpMethod.get);
        when(() => request.uri).thenReturn(
          Uri.parse('http://localhost/api/v1/mobile/sync/pull'),
        );

        final now = DateTime.utc(2026, 9, 30, 10);
        when(() => client.fetchWorkflows(any())).thenAnswer(
          (_) async => [
            Workflow(
              id: 1,
              userId: 42,
              name: 'PPL - Push A',
              createdAt: now,
              updatedAt: now,
            ),
            Workflow(
              id: 2,
              userId: 42,
              name: 'PPL - Pull A (Deletado)',
              createdAt: now,
              updatedAt: now,
              deletedAt: now,
            ),
          ],
        );

        final response = await route.onRequest(context);

        expect(response.statusCode, equals(HttpStatus.ok));

        final body = await response.json() as Map<String, dynamic>;
        final result = SyncPullResponse.fromJson(body);

        expect(result.updatedWorkflows.length, equals(1));
        expect(result.updatedWorkflows.first.name, equals('PPL - Push A'));
        expect(result.deletedWorkflowIds, isEmpty);
      },
    );

    test(
      'returns delta updates and deleted ids when last_synced_at is provided',
      () async {
        when(() => request.method).thenReturn(HttpMethod.get);
        when(() => request.uri).thenReturn(
          Uri.parse(
            'http://localhost/api/v1/mobile/sync/pull?last_synced_at=2026-09-30T10:00:00.000Z',
          ),
        );

        final before = DateTime.utc(2026, 9, 30, 9);
        final after = DateTime.utc(2026, 9, 30, 11);

        when(() => client.fetchWorkflows(any())).thenAnswer(
          (_) async => [
            Workflow(
              id: 1,
              userId: 42,
              name: 'Rotina Antiga (Sem alteração)',
              createdAt: before,
              updatedAt: before,
            ),
            Workflow(
              id: 2,
              userId: 42,
              name: 'Rotina Editada pelo Treinador',
              createdAt: before,
              updatedAt: after,
            ),
            Workflow(
              id: 3,
              userId: 42,
              name: 'Rotina Removida',
              createdAt: before,
              updatedAt: after,
              deletedAt: after,
            ),
          ],
        );

        final response = await route.onRequest(context);

        expect(response.statusCode, equals(HttpStatus.ok));

        final body = await response.json() as Map<String, dynamic>;
        final result = SyncPullResponse.fromJson(body);

        expect(result.updatedWorkflows.length, equals(1));
        expect(result.updatedWorkflows.first.id, equals(2));
        expect(result.deletedWorkflowIds, equals([3]));
      },
    );
  });
}
