import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/features/sync/application/sync_engine.dart';
import 'package:repengine_mobile/features/sync/data/sync_http_client.dart';
import 'package:repengine_mobile/features/workout_execution/data/workout_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSyncHttpClient implements SyncHttpClient {
  SyncPushResult? pushResponse;
  SyncPullResponse? pullResponse;
  SyncPushPayload? capturedPayload;
  DateTime? capturedLastSyncedAt;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<SyncPushResult?> pushMutations(SyncPushPayload payload) async {
    capturedPayload = payload;
    return pushResponse;
  }

  @override
  Future<SyncPullResponse?> pullWorkflows({DateTime? lastSyncedAt}) async {
    capturedLastSyncedAt = lastSyncedAt;
    return pullResponse;
  }
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Deterministic Conflict Resolution (Coach vs Athlete)', () {
    test(
      'Athlete offline logs are never lost when Coach updates routine concurrently on web',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final repository = WorkoutRepository(db);
        final fakeClient = FakeSyncHttpClient();
        final prefs = await SharedPreferences.getInstance();

        final syncEngine = SyncEngine(
          httpClient: fakeClient,
          repository: repository,
          db: db,
          prefs: prefs,
        );

        // 1. Initial State: Routine v1 synced from coach
        final v1Timestamp = DateTime.utc(2026, 10, 8, 8, 0, 0);
        final routineV1 = Workflow(
          id: 10,
          userId: 1,
          name: 'Hypertrophy Push A (Coach v1)',
          description: 'Original routine',
          isPublic: true,
          createdAt: v1Timestamp,
          updatedAt: v1Timestamp,
          blockCount: 2,
          blocks: [
            const WorkflowBlock(
              id: 1,
              workflowId: 10,
              nodeTypeSlug: 'section',
              position: 1,
              data: {'title': 'Push Day'},
            ),
            const WorkflowBlock(
              id: 2,
              workflowId: 10,
              nodeTypeSlug: 'exercise_bench',
              position: 2,
              data: {'exercise_name': 'Flat Barbell Bench Press', 'sets': 3, 'reps': '8', 'load': 80.0},
            ),
          ],
        );
        await repository.upsertWorkflows([routineV1]);

        // 2. Athlete goes offline and trains at gym
        final sessionTime = DateTime.utc(2026, 10, 8, 10, 0, 0);
        const sessionClientId = 'sess-offline-athlete-99';

        await repository.startSession(
          clientId: sessionClientId,
          workflowId: 10,
          sectionId: 'sec_day1',
          sectionTitle: 'Push Day',
          startedAt: sessionTime,
        );

        // Athlete logs 3 completed sets with actual gym numbers
        await repository.logSet(
          clientId: 'log-ath-1',
          sessionClientId: sessionClientId,
          blockClientId: 'blk_bench',
          nodeTypeSlug: 'exercise_bench',
          setIndex: 1,
          prescribedReps: '8',
          prescribedLoad: '80.0',
          actualReps: '8',
          actualLoad: '80.0',
          actualRpe: '8.0',
          completed: true,
          createdAt: sessionTime.add(const Duration(minutes: 5)),
        );

        await repository.logSet(
          clientId: 'log-ath-2',
          sessionClientId: sessionClientId,
          blockClientId: 'blk_bench',
          nodeTypeSlug: 'exercise_bench',
          setIndex: 2,
          prescribedReps: '8',
          prescribedLoad: '80.0',
          actualReps: '8',
          actualLoad: '80.0',
          actualRpe: '8.5',
          completed: true,
          createdAt: sessionTime.add(const Duration(minutes: 9)),
        );

        await repository.logSet(
          clientId: 'log-ath-3',
          sessionClientId: sessionClientId,
          blockClientId: 'blk_bench',
          nodeTypeSlug: 'exercise_bench',
          setIndex: 3,
          prescribedReps: '8',
          prescribedLoad: '80.0',
          actualReps: '7',
          actualLoad: '80.0',
          actualRpe: '10.0',
          completed: true,
          createdAt: sessionTime.add(const Duration(minutes: 13)),
        );

        await repository.completeSession(sessionClientId);

        // Verify outbox has 5 pending mutations: 1 session create, 3 sets create, 1 session complete
        final pendingBeforeSync = await (db.select(db.syncQueueTable)
              ..where((t) => t.status.equals('pending')))
            .get();
        expect(pendingBeforeSync.length, equals(5));

        // 3. Concurrently, Coach on Web updates Routine #10 to v2 (adds Dumbbell Flyes)
        final v2Timestamp = DateTime.utc(2026, 10, 8, 10, 15, 0);
        final routineV2 = Workflow(
          id: 10,
          userId: 1,
          name: 'Hypertrophy Push A (Coach v2 - Revised)',
          description: 'Updated with accessory flyes',
          isPublic: true,
          createdAt: v1Timestamp,
          updatedAt: v2Timestamp,
          blockCount: 3,
          blocks: [
            const WorkflowBlock(
              id: 1,
              workflowId: 10,
              nodeTypeSlug: 'section',
              position: 1,
              data: {'title': 'Push Day'},
            ),
            const WorkflowBlock(
              id: 2,
              workflowId: 10,
              nodeTypeSlug: 'exercise_bench',
              position: 2,
              data: {'exercise_name': 'Flat Barbell Bench Press', 'sets': 3, 'reps': '8', 'load': 80.0},
            ),
            const WorkflowBlock(
              id: 3,
              workflowId: 10,
              nodeTypeSlug: 'exercise_fly',
              position: 3,
              data: {'exercise_name': 'Incline Dumbbell Fly', 'sets': 3, 'reps': '12', 'load': 18.0},
            ),
          ],
        );

        // 4. Athlete reconnects to network and triggers syncNow()
        // Fake Push: Server accepts all athlete mutations with no conflicts
        fakeClient.pushResponse = SyncPushResult(
          processedAt: DateTime.now().toUtc(),
          items: const [
            SyncPushItemStatus(
              clientId: sessionClientId,
              status: SyncItemStatus.accepted,
              serverId: 501,
            ),
            SyncPushItemStatus(
              clientId: 'log-ath-1',
              status: SyncItemStatus.accepted,
              serverId: 601,
            ),
            SyncPushItemStatus(
              clientId: 'log-ath-2',
              status: SyncItemStatus.accepted,
              serverId: 602,
            ),
            SyncPushItemStatus(
              clientId: 'log-ath-3',
              status: SyncItemStatus.accepted,
              serverId: 603,
            ),
          ],
        );

        // Fake Pull: Server delivers Coach's updated workflow v2
        fakeClient.pullResponse = SyncPullResponse(
          serverTimestamp: v2Timestamp,
          updatedWorkflows: [routineV2],
          deletedWorkflowIds: [],
          progressionStates: [],
        );

        final syncResult = await syncEngine.syncNow();
        expect(syncResult, isTrue);

        // 5. Verification:
        // A) Athlete's workout session is 100% intact locally
        final localSessions = await (db.select(db.workoutSessionsTable)
              ..where((t) => t.clientId.equals(sessionClientId)))
            .get();
        expect(localSessions.length, equals(1));
        expect(localSessions.first.status, equals('completed'));
        expect(localSessions.first.workflowId, equals(10));

        // B) All 3 athlete sets are 100% intact with exact weights and RPEs
        final localLogs = await (db.select(db.workoutSetLogsTable)
              ..where((t) => t.sessionClientId.equals(sessionClientId))
              ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
            .get();
        expect(localLogs.length, equals(3));
        expect(localLogs[0].clientId, equals('log-ath-1'));
        expect(localLogs[0].actualLoad, equals('80.0'));
        expect(localLogs[0].actualRpe, equals('8.0'));
        expect(localLogs[2].clientId, equals('log-ath-3'));
        expect(localLogs[2].actualReps, equals('7'));
        expect(localLogs[2].actualRpe, equals('10.0'));

        // C) Local routine is cleanly updated to Coach v2 without touching workout history
        final localRoutine = await repository.getRoutineById(10);
        expect(localRoutine, isNotNull);
        expect(localRoutine!.name, equals('Hypertrophy Push A (Coach v2 - Revised)'));
        expect(localRoutine.blockCount, equals(3));
        expect(localRoutine.updatedAt.isAtSameMomentAs(v2Timestamp), isTrue);
        expect(localRoutine.blocksJson.contains('Incline Dumbbell Fly'), isTrue);

        // D) Outbox queue confirmed items are cleanly purged
        final remainingPending = await (db.select(db.syncQueueTable)
              ..where((t) => t.status.equals('pending')))
            .get();
        expect(remainingPending.isEmpty, isTrue);

        await db.close();
      },
    );
  });
}
