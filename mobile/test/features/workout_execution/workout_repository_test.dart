import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/features/workout_execution/data/workout_repository.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = WorkoutRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('startSession saves session and enqueues mutation atomically in outbox', () async {
    final session = await repository.startSession(
      clientId: 'sess-100',
      workflowId: 2,
      sectionId: 'sec_a',
      sectionTitle: 'Workout A',
      startedAt: DateTime.utc(2026, 10, 3, 14),
    );

    expect(session.clientId, equals('sess-100'));
    expect(session.status, equals('active'));

    // Verify outbox received the item
    final queue = await db.select(db.syncQueueTable).get();
    expect(queue, hasLength(1));
    expect(queue.first.entityClientId, equals('sess-100'));
    expect(queue.first.action, equals('CREATE'));
  });

  test('watchActiveSession and watchSessionLogs emit real-time updates', () async {
    // 1. Start workout
    await repository.startSession(
      clientId: 'sess-200',
      workflowId: 1,
      sectionId: 'sec_b',
      sectionTitle: 'Workout B',
      startedAt: DateTime.utc(2026, 10, 3, 15),
    );

    // 2. Log set
    await repository.logSet(
      clientId: 'log-1',
      sessionClientId: 'sess-200',
      blockClientId: 'blk_1',
      nodeTypeSlug: 'exercise_squat',
      setIndex: 1,
      prescribedReps: '5',
      prescribedLoad: '100.0',
      actualReps: '5',
      actualLoad: '102.5',
      actualRpe: '8.5',
      completed: true,
      createdAt: DateTime.utc(2026, 10, 3, 15, 5),
    );

    // 3. Test streams
    final active = await repository.watchActiveSession().first;
    expect(active?.clientId, equals('sess-200'));

    final logs = await repository.watchSessionLogs('sess-200').first;
    expect(logs, hasLength(1));
    expect(logs.first.actualLoad, equals('102.5'));

    final pending = await repository.watchPendingSyncCount().first;
    expect(pending, equals(2)); // 1 session + 1 set
  });

  test('completeSession updates status and enqueues UPDATE mutation in outbox', () async {
    await repository.startSession(
      clientId: 'sess-300',
      workflowId: 1,
      sectionId: 'sec_c',
      sectionTitle: 'Workout C',
      startedAt: DateTime.utc(2026, 10, 3, 16),
    );

    await repository.completeSession('sess-300');

    final active = await repository.watchActiveSession().first;
    expect(active, isNull);

    final queue = await db.select(db.syncQueueTable).get();
    expect(queue, hasLength(2)); // 1 CREATE + 1 UPDATE
    expect(queue.last.action, equals('UPDATE'));
  });

  test('getSuggestedProgressionForBlock calculates progressive overload (+2.5 kg) after previous completed session', () async {
    // 1. Session 1 finished with 105 kg x 5 reps @ RPE 8.0
    await repository.startSession(
      clientId: 'sess-prev',
      workflowId: 1,
      sectionId: 'sec_1',
      sectionTitle: 'Workout A',
      startedAt: DateTime.utc(2026, 10, 1, 10),
    );

    await repository.logSet(
      clientId: 'log-prev-1',
      sessionClientId: 'sess-prev',
      blockClientId: 'blk_squat',
      nodeTypeSlug: 'exercise_squat',
      setIndex: 1,
      prescribedReps: '5',
      prescribedLoad: '105.0',
      actualReps: '5',
      actualLoad: '105.0',
      actualRpe: '8.0',
      completed: true,
      createdAt: DateTime.utc(2026, 10, 1, 10, 5),
    );

    await repository.completeSession('sess-prev');

    // 2. Query suggestion for next workout (no active session)
    final suggestion = await repository.getSuggestedProgressionForBlock('blk_squat');

    // Target reached with submaximal RPE (8.0): 105.0 + 2.5 = 107.5 kg!
    expect(suggestion.load, equals(107.5));
    expect(suggestion.reps, equals(5));
    expect(suggestion.isProgressed, isTrue);
    expect(suggestion.reasoning, contains('107.5 kg'));
  });

  test('getSuggestedProgressionForBlock maintains load from previous set within same active session', () async {
    // 1. Current active session
    await repository.startSession(
      clientId: 'sess-now',
      workflowId: 1,
      sectionId: 'sec_1',
      sectionTitle: 'Workout A',
      startedAt: DateTime.utc(2026, 10, 7, 10),
    );

    // 2. Log set 1 with 110 kg
    await repository.logSet(
      clientId: 'log-now-1',
      sessionClientId: 'sess-now',
      blockClientId: 'blk_squat',
      nodeTypeSlug: 'exercise_squat',
      setIndex: 1,
      prescribedReps: '5',
      prescribedLoad: '110.0',
      actualReps: '5',
      actualLoad: '110.0',
      actualRpe: '8.5',
      completed: true,
      createdAt: DateTime.utc(2026, 10, 7, 10, 5),
    );

    // 3. Query suggestion for set 2
    final suggestion = await repository.getSuggestedProgressionForBlock('blk_squat');

    // Should inherit 110.0 kg from set 1
    expect(suggestion.load, equals(110.0));
    expect(suggestion.reps, equals(5));
    expect(suggestion.isProgressed, isFalse);
    expect(suggestion.reasoning, contains('Maintaining load from previous set'));
  });

  test('upsertWorkflows, deleteWorkflows, watchRoutines, and deleteQueueItemsByClientIds work correctly', () async {
    final now = DateTime.utc(2026, 10, 8, 10);
    final workflowA = Workflow(
      id: 10,
      userId: 1,
      name: 'Upper Body A',
      description: 'Push & Pull',
      blockCount: 4,
      createdAt: now,
      updatedAt: now,
    );

    // 1. Test Upsert (Insert)
    await repository.upsertWorkflows([workflowA]);
    var routines = await db.select(db.routinesTable).get();
    expect(routines, hasLength(1));
    expect(routines.first.name, equals('Upper Body A'));

    // 2. Test watchRoutines stream
    final routinesStreamFuture = repository.watchRoutines().first;
    final streamedRoutines = await routinesStreamFuture;
    expect(streamedRoutines, hasLength(1));
    expect(streamedRoutines.first.name, equals('Upper Body A'));

    // 3. Test Upsert (Update existing)
    final workflowAUpdated = Workflow(
      id: 10,
      userId: 1,
      name: 'Upper Body A (Updated)',
      description: 'Updated desc',
      blockCount: 5,
      createdAt: now,
      updatedAt: now.add(const Duration(hours: 1)),
    );
    await repository.upsertWorkflows([workflowAUpdated]);
    routines = await db.select(db.routinesTable).get();
    expect(routines, hasLength(1));
    expect(routines.first.name, equals('Upper Body A (Updated)'));
    expect(routines.first.blockCount, equals(5));

    // 4. Test Delete
    await repository.deleteWorkflows([10]);
    routines = await db.select(db.routinesTable).get();
    expect(routines, isEmpty);

    // 5. Test deleteQueueItemsByClientIds
    await repository.startSession(
      clientId: 'sess-to-purge',
      workflowId: 1,
      sectionId: 'sec_1',
      sectionTitle: 'Workout A',
      startedAt: now,
    );
    var queue = await db.select(db.syncQueueTable).get();
    expect(queue, hasLength(1));
    expect(queue.first.entityClientId, equals('sess-to-purge'));

    await repository.deleteQueueItemsByClientIds(['sess-to-purge']);
    queue = await db.select(db.syncQueueTable).get();
    expect(queue, isEmpty);
  });

  test('upsertProgressionStates saves prescribed loads and powers getSuggestedProgressionForBlock', () async {
    const blockKey = 'blk-bench-heavy';
    final now = DateTime.utc(2026, 10, 8, 10);

    final progression = ProgressionState(
      id: 50,
      userId: 1,
      workflowId: 2,
      blockKey: blockKey,
      nodeTypeSlug: 'exercise_bench',
      stateType: 'linear',
      outcome: 'success',
      suggestedLoad: '92.5',
      currentWeek: 2,
      suggestedWeek: 3,
      summary: 'Wave 2 Target: +2.5 kg',
      updatedAt: now,
    );

    // 1. Save progression state to SQLite
    await repository.upsertProgressionStates([progression]);

    // 2. Verify saved in database
    final saved = await repository.getProgressionStateForBlock(blockKey);
    expect(saved, isNotNull);
    expect(saved!.suggestedLoad, equals('92.5'));
    expect(saved.summary, equals('Wave 2 Target: +2.5 kg'));

    // 3. Verify getSuggestedProgressionForBlock picks up prescribed load 92.5 kg
    final suggestion = await repository.getSuggestedProgressionForBlock(blockKey);
    expect(suggestion.load, equals(92.5));
    expect(suggestion.reasoning, equals('Wave 2 Target: +2.5 kg'));
    expect(suggestion.isProgressed, isFalse);
  });

  test('abandonSession purges session, sets, and pending outbox mutations cleanly (deleteSession: true)', () async {
    // 1. Start workout session
    await repository.startSession(
      clientId: 'sess-abandon-1',
      workflowId: 1,
      sectionId: 'sec_test',
      sectionTitle: 'Workout Abandon Test',
      startedAt: DateTime.utc(2026, 10, 8, 12),
    );

    // 2. Log 2 sets
    await repository.logSet(
      clientId: 'log-abandon-1',
      sessionClientId: 'sess-abandon-1',
      blockClientId: 'blk_1',
      nodeTypeSlug: 'exercise_squat',
      setIndex: 1,
      prescribedReps: '5',
      prescribedLoad: '100.0',
      actualReps: '5',
      actualLoad: '100.0',
      actualRpe: '8.0',
      completed: true,
      createdAt: DateTime.utc(2026, 10, 8, 12, 5),
    );

    await repository.logSet(
      clientId: 'log-abandon-2',
      sessionClientId: 'sess-abandon-1',
      blockClientId: 'blk_1',
      nodeTypeSlug: 'exercise_squat',
      setIndex: 2,
      prescribedReps: '5',
      prescribedLoad: '100.0',
      actualReps: '5',
      actualLoad: '100.0',
      actualRpe: '8.5',
      completed: true,
      createdAt: DateTime.utc(2026, 10, 8, 12, 10),
    );

    // Verify outbox currently contains 3 items
    var queue = await db.select(db.syncQueueTable).get();
    expect(queue, hasLength(3));

    // 3. Abandon session
    await repository.abandonSession('sess-abandon-1', deleteSession: true);

    // Verify active session is null
    final active = await repository.watchActiveSession().first;
    expect(active, isNull);

    // Verify session row is deleted
    final sessions = await db.select(db.workoutSessionsTable).get();
    expect(sessions, isEmpty);

    // Verify set logs are purged
    final logs = await db.select(db.workoutSetLogsTable).get();
    expect(logs, isEmpty);

    // Verify outbox mutations are purged so nothing dirty syncs to server
    queue = await db.select(db.syncQueueTable).get();
    expect(queue, isEmpty);
  });

  test('abandonSession marks status as abandoned when deleteSession: false', () async {
    // 1. Start workout session
    await repository.startSession(
      clientId: 'sess-abandon-2',
      workflowId: 1,
      sectionId: 'sec_test_2',
      sectionTitle: 'Workout Abandon Status Test',
      startedAt: DateTime.utc(2026, 10, 8, 13),
    );

    // 2. Log 1 set
    await repository.logSet(
      clientId: 'log-abandon-3',
      sessionClientId: 'sess-abandon-2',
      blockClientId: 'blk_2',
      nodeTypeSlug: 'exercise_bench',
      setIndex: 1,
      prescribedReps: '5',
      prescribedLoad: '80.0',
      actualReps: '5',
      actualLoad: '80.0',
      actualRpe: '7.5',
      completed: true,
      createdAt: DateTime.utc(2026, 10, 8, 13, 5),
    );

    // 3. Abandon with deleteSession: false
    await repository.abandonSession('sess-abandon-2', deleteSession: false);

    // Verify active session is null
    final active = await repository.watchActiveSession().first;
    expect(active, isNull);

    // Verify session row is retained with status 'abandoned'
    final session = await (db.select(db.workoutSessionsTable)
          ..where((t) => t.clientId.equals('sess-abandon-2')))
        .getSingle();
    expect(session.status, equals('abandoned'));
    expect(session.completedAt, isNotNull);

    // Verify set logs and queue are purged
    final logs = await db.select(db.workoutSetLogsTable).get();
    expect(logs, isEmpty);

    final queue = await db.select(db.syncQueueTable).get();
    expect(queue, isEmpty);
  });
}


