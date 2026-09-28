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
  });
}
