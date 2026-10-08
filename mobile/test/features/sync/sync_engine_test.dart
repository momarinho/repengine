import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/network/server_config.dart';
import 'package:repengine_mobile/features/sync/application/sync_engine.dart';
import 'package:repengine_mobile/features/sync/data/sync_http_client.dart';
import 'package:repengine_mobile/features/workout_execution/data/workout_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late WorkoutRepository repository;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = WorkoutRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Full Sync Cycle: pushes queued mutations, purges queue, and pulls workflows into SQLite', () async {
    // 1. Prepare offline data in SQLite
    final session = await repository.startSession(
      clientId: 'sess-offline-1',
      workflowId: 10,
      sectionId: 'sec-a',
      sectionTitle: 'Push Day',
      startedAt: DateTime.utc(2026, 10, 8, 9),
    );
    expect(session.clientId, equals('sess-offline-1'));

    final setLog = await repository.logSet(
      clientId: 'log-offline-1',
      sessionClientId: 'sess-offline-1',
      blockClientId: 'blk-bench',
      nodeTypeSlug: 'exercise_bench',
      setIndex: 1,
      prescribedReps: '5',
      prescribedLoad: '80.0',
      actualReps: '5',
      actualLoad: '80.0',
      actualRpe: '8.0',
      completed: true,
      createdAt: DateTime.utc(2026, 10, 8, 9, 5),
    );
    expect(setLog.clientId, equals('log-offline-1'));

    // Check queue has 2 pending items
    var queue = await db.select(db.syncQueueTable).get();
    expect(queue, hasLength(2));

    var pushCalled = false;
    var pullCalled = false;

    // 2. Mock Dart Frog BFF HTTP responses
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/push') && request.method == 'POST') {
        pushCalled = true;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final sessions = body['sessions'] as List;
        final setLogs = body['set_logs'] as List;
        expect(sessions, hasLength(1));
        expect(setLogs, hasLength(1));

        final response = {
          'items': [
            {'client_id': 'sess-offline-1', 'status': 'accepted', 'server_id': 101},
            {'client_id': 'log-offline-1', 'status': 'accepted', 'server_id': 202},
          ],
          'processed_at': '2026-10-08T10:00:00Z',
        };
        return http.Response(jsonEncode(response), 200);
      }

      if (request.url.path.endsWith('/pull') && request.method == 'GET') {
        pullCalled = true;
        final response = {
          'updated_workflows': [
            {
              'id': 10,
              'user_id': 1,
              'name': 'Push Pull Legs - Push',
              'description': 'Hypertrophy cycle',
              'is_public': false,
              'created_at': '2026-10-01T10:00:00Z',
              'updated_at': '2026-10-08T09:30:00Z',
              'block_count': 4,
              'blocks': [],
            }
          ],
          'deleted_workflow_ids': [],
          'server_timestamp': '2026-10-08T10:00:01Z',
        };
        return http.Response(jsonEncode(response), 200);
      }

      return http.Response('Not Found', 404);
    });

    final httpClient = SyncHttpClient(
      client: mockClient,
      baseUrl: 'http://localhost:8081',
    );

    final syncEngine = SyncEngine(
      httpClient: httpClient,
      repository: repository,
      db: db,
      prefs: prefs,
    );

    // 3. Execute syncNow()
    final success = await syncEngine.syncNow();
    expect(success, isTrue);
    expect(pushCalled, isTrue);
    expect(pullCalled, isTrue);

    // 4. Assert queue was atomically purged
    queue = await db.select(db.syncQueueTable).get();
    expect(queue, isEmpty);

    // 5. Assert workflows were upserted into RoutinesTable
    final routines = await db.select(db.routinesTable).get();
    expect(routines, hasLength(1));
    expect(routines.first.name, equals('Push Pull Legs - Push'));

    // 6. Assert SharedPreferences has updated timestamp
    expect(prefs.getString('repengine_last_synced_at'), equals('2026-10-08T10:00:01.000Z'));
    expect(syncEngine.state.status, equals(SyncStatus.success));
  });

  test('SyncEngine gracefully handles push failure without data loss in outbox queue', () async {
    // 1. Add item to queue
    await repository.startSession(
      clientId: 'sess-retry-1',
      workflowId: 5,
      sectionId: 'sec-1',
      sectionTitle: 'Workout',
      startedAt: DateTime.utc(2026, 10, 8, 9),
    );

    final mockClient = MockClient((request) async {
      return http.Response('Internal Server Error', 500);
    });

    final httpClient = SyncHttpClient(
      client: mockClient,
      baseUrl: 'http://localhost:8081',
    );

    final syncEngine = SyncEngine(
      httpClient: httpClient,
      repository: repository,
      db: db,
      prefs: prefs,
    );

    final success = await syncEngine.syncNow();
    expect(success, isFalse);
    expect(syncEngine.state.status, equals(SyncStatus.error));

    // Data in queue is intact!
    final queue = await db.select(db.syncQueueTable).get();
    expect(queue, hasLength(1));
    expect(queue.first.entityClientId, equals('sess-retry-1'));
  });

  test('SyncEngine persists progression states received during pull phase', () async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/pull')) {
        final response = {
          'updated_workflows': [],
          'deleted_workflow_ids': [],
          'progression_states': [
            {
              'id': 101,
              'user_id': 1,
              'workflow_id': 20,
              'block_key': 'blk-ohp',
              'node_type_slug': 'exercise_overhead_press',
              'state_type': 'linear',
              'outcome': 'progressed',
              'suggested_load': '62.5',
              'current_week': 3,
              'suggested_week': 4,
              'summary': 'Week 4 Target: +2.5 kg',
              'updated_at': '2026-10-08T10:00:00Z',
            }
          ],
          'server_timestamp': '2026-10-08T10:00:05Z',
        };
        return http.Response(jsonEncode(response), 200);
      }
      return http.Response('Not Found', 404);
    });

    final httpClient = SyncHttpClient(
      client: mockClient,
      baseUrl: 'http://localhost:8081',
    );

    final syncEngine = SyncEngine(
      httpClient: httpClient,
      repository: repository,
      db: db,
      prefs: prefs,
    );

    final success = await syncEngine.syncNow();
    expect(success, isTrue);

    // Verify progression state was saved to SQLite
    final states = await db.select(db.progressionStatesTable).get();
    expect(states, hasLength(1));
    expect(states.first.blockKey, equals('blk-ohp'));
    expect(states.first.suggestedLoad, equals('62.5'));
    expect(states.first.summary, equals('Week 4 Target: +2.5 kg'));
  });

  test('handleHealthChange auto-syncs when online and respects simulateOffline', () async {
    var syncTriggered = false;

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/pull')) {
        syncTriggered = true;
        return http.Response(jsonEncode({
          'updated_workflows': [],
          'deleted_workflow_ids': [],
          'server_timestamp': '2026-10-08T10:00:00Z',
        }), 200);
      }
      return http.Response('Not Found', 404);
    });

    final httpClient = SyncHttpClient(
      client: mockClient,
      baseUrl: 'http://localhost:8081',
    );

    final syncEngine = SyncEngine(
      httpClient: httpClient,
      repository: repository,
      db: db,
      prefs: prefs,
    );

    final nowTime = DateTime.utc(2026, 10, 8, 10);
    final onlineHealth = ServerConnectionState(
      state: ConnectionStateEnum.online,
      latencyMs: 15,
      lastCheckedAt: nowTime,
      errorMessage: null,
    );

    // 1. Should NOT sync when simulateOffline is true
    syncEngine.handleHealthChange(onlineHealth, true);
    expect(syncTriggered, isFalse);

    // 2. Should NOT sync when offline
    final offlineHealth = ServerConnectionState(
      state: ConnectionStateEnum.offline,
      latencyMs: null,
      lastCheckedAt: nowTime,
      errorMessage: 'offline',
    );
    syncEngine.handleHealthChange(offlineHealth, false);
    expect(syncTriggered, isFalse);

    // 3. Should trigger auto-sync when online and not simulated offline
    syncEngine.handleHealthChange(onlineHealth, false);
    // Allow async execution
    await pumpEventQueue();
    expect(syncTriggered, isTrue);
  });
}

