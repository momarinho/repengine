import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repengine_core/repengine_core.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class ProgressionSuggestion {
  final double load;
  final int reps;
  final String? reasoning;
  final bool isProgressed;

  const ProgressionSuggestion({
    required this.load,
    required this.reps,
    this.reasoning,
    this.isProgressed = false,
  });
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(ref.watch(appDatabaseProvider));
});

class WorkoutRepository {
  final AppDatabase _db;

  WorkoutRepository(this._db);

  // ==========================================
  // REACTIVE STREAMS (Real-time UI listening)
  // ==========================================

  /// Listens to the currently active workout session.
  /// If the user closes and reopens the app, the UI immediately restores active state.
  Stream<WorkoutSessionData?> watchActiveSession() {
    return (_db.select(_db.workoutSessionsTable)
          ..where((t) => t.status.equals('active'))
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Listens to all sets logged for a session in order of completion.
  Stream<List<WorkoutSetLogData>> watchSessionLogs(String sessionClientId) {
    return (_db.select(_db.workoutSetLogsTable)
          ..where((t) => t.sessionClientId.equals(sessionClientId))
          ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
        .watch();
  }

  /// Listens to the count of pending mutations in the sync queue.
  /// The UI uses this for the sync badge ("3 pending" or "Synced").
  Stream<int> watchPendingSyncCount() {
    final countExp = _db.syncQueueTable.id.count();
    final query = _db.selectOnly(_db.syncQueueTable)
      ..addColumns([countExp])
      ..where(_db.syncQueueTable.status.equals('pending'));

    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  /// Returns stream of all outbox queue items for inspection and diagnostics.
  Stream<List<SyncQueueData>> watchSyncQueue() {
    return (_db.select(_db.syncQueueTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  // ==========================================
  // ATOMIC OPERATIONS (Local Storage + Outbox)
  // ==========================================

  /// Starts a new workout session and enqueues for synchronization.
  Future<WorkoutSessionData> startSession({
    required String clientId,
    required int workflowId,
    required String sectionId,
    required String sectionTitle,
    required DateTime startedAt,
  }) async {
    return _db.transaction(() async {
      // 1. Write session locally to SQLite
      final sessionCompanion = WorkoutSessionsTableCompanion.insert(
        clientId: clientId,
        workflowId: workflowId,
        sectionId: sectionId,
        sectionTitle: sectionTitle,
        status: const Value('active'),
        startedAt: startedAt,
      );

      final sessionId =
          await _db.into(_db.workoutSessionsTable).insert(sessionCompanion);

      // 2. Write mutation to Outbox queue (sync_queue)
      final payload = jsonEncode({
        'client_id': clientId,
        'workflow_id': workflowId,
        'section_id': sectionId,
        'section_title': sectionTitle,
        'status': 'active',
        'started_at': startedAt.toUtc().toIso8601String(),
      });

      await _db.into(_db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              entityClientId: clientId,
              entityType: 'session',
              action: 'CREATE',
              payload: payload,
              createdAt: DateTime.now().toUtc(),
            ),
          );

      return (_db.select(_db.workoutSessionsTable)
            ..where((t) => t.id.equals(sessionId)))
          .getSingle();
    });
  }

  /// Logs a completed set and enqueues for synchronization.
  Future<WorkoutSetLogData> logSet({
    required String clientId,
    required String sessionClientId,
    required String blockClientId,
    required String nodeTypeSlug,
    required int setIndex,
    required String prescribedReps,
    required String prescribedLoad,
    required String actualReps,
    required String actualLoad,
    required String actualRpe,
    required bool completed,
    required DateTime createdAt,
  }) async {
    return _db.transaction(() async {
      // 1. Save set to local SQLite
      final setCompanion = WorkoutSetLogsTableCompanion.insert(
        clientId: clientId,
        sessionClientId: sessionClientId,
        blockClientId: blockClientId,
        nodeTypeSlug: nodeTypeSlug,
        setIndex: setIndex,
        prescribedReps: Value(prescribedReps),
        prescribedLoad: Value(prescribedLoad),
        actualReps: Value(actualReps),
        actualLoad: Value(actualLoad),
        actualRpe: Value(actualRpe),
        completed: Value(completed),
        createdAt: createdAt,
      );

      final logId =
          await _db.into(_db.workoutSetLogsTable).insert(setCompanion);

      // 2. Enqueue atomic mutation to sync_queue
      final payload = jsonEncode({
        'client_id': clientId,
        'session_client_id': sessionClientId,
        'block_client_id': blockClientId,
        'node_type_slug': nodeTypeSlug,
        'set_index': setIndex,
        'prescribed_reps': prescribedReps,
        'prescribed_load': prescribedLoad,
        'actual_reps': actualReps,
        'actual_load': actualLoad,
        'actual_rpe': actualRpe,
        'completed': completed,
        'created_at': createdAt.toUtc().toIso8601String(),
      });

      await _db.into(_db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              entityClientId: clientId,
              entityType: 'set_log',
              action: 'CREATE',
              payload: payload,
              createdAt: DateTime.now().toUtc(),
            ),
          );

      return (_db.select(_db.workoutSetLogsTable)
            ..where((t) => t.id.equals(logId)))
          .getSingle();
    });
  }

  /// Completes active workout session.
  Future<void> completeSession(String sessionClientId) async {
    await _db.transaction(() async {
      final now = DateTime.now().toUtc();

      await (_db.update(_db.workoutSessionsTable)
            ..where((t) => t.clientId.equals(sessionClientId)))
          .write(
        WorkoutSessionsTableCompanion(
          status: const Value('completed'),
          completedAt: Value(now),
        ),
      );

      await _db.into(_db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              entityClientId: sessionClientId,
              entityType: 'session',
              action: 'UPDATE',
              payload: jsonEncode({
                'client_id': sessionClientId,
                'status': 'completed',
                'completed_at': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });
  }

  /// Dynamically computes recommended load and repetitions for the next set in the block,
  /// integrating local SQLite history with repengine_core AutoregulationEngine.
  Future<ProgressionSuggestion> getSuggestedProgressionForBlock(
    String blockClientId, {
    double fallbackLoad = 100.0,
    int fallbackReps = 5,
  }) async {
    // 1. Check if sets were already completed in the current active session
    final activeSession = await (_db.select(_db.workoutSessionsTable)
          ..where((t) => t.status.equals('active'))
          ..limit(1))
        .getSingleOrNull();

    if (activeSession != null) {
      final currentSessionSets = await (_db.select(_db.workoutSetLogsTable)
            ..where((t) =>
                t.sessionClientId.equals(activeSession.clientId) &
                t.blockClientId.equals(blockClientId) &
                t.completed.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.setIndex)]))
          .get();

      if (currentSessionSets.isNotEmpty) {
        final lastSet = currentSessionSets.first;
        final load = double.tryParse(lastSet.actualLoad) ?? fallbackLoad;
        final reps = int.tryParse(lastSet.actualReps) ?? fallbackReps;
        return ProgressionSuggestion(
          load: load,
          reps: reps,
          reasoning: 'Maintaining load from previous set (#${lastSet.setIndex})',
          isProgressed: false,
        );
      }
    }

    // 2. If at session start (no sets yet), query historical completed sessions
    final allHistoricalLogs = await (_db.select(_db.workoutSetLogsTable)
          ..where((t) =>
              t.blockClientId.equals(blockClientId) &
              t.completed.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    final pastLogs = activeSession != null
        ? allHistoricalLogs
            .where((l) => l.sessionClientId != activeSession.clientId)
            .toList()
        : allHistoricalLogs;

    if (pastLogs.isEmpty) {
      return ProgressionSuggestion(
        load: fallbackLoad,
        reps: fallbackReps,
        reasoning: 'Initial recommended load',
        isProgressed: false,
      );
    }

    // Group sets from the most recent completed session
    final lastSessionClientId = pastLogs.first.sessionClientId;
    final lastSessionLogs = pastLogs
        .where((l) => l.sessionClientId == lastSessionClientId)
        .toList();

    double maxLoad = 0.0;
    int targetReps = fallbackReps;
    double? lastRpe;
    bool anyFailed = false;

    for (final log in lastSessionLogs) {
      final load = double.tryParse(log.actualLoad) ?? 0.0;
      if (load > maxLoad) maxLoad = load;
      final reps = int.tryParse(log.actualReps) ?? 0;
      final prescribed = int.tryParse(log.prescribedReps) ?? fallbackReps;
      targetReps = prescribed;
      if (log.actualRpe.isNotEmpty) {
        final rpe = double.tryParse(log.actualRpe);
        if (rpe != null) lastRpe = rpe;
      }
      if (reps < prescribed) {
        anyFailed = true;
      }
    }

    final historicalSession = HistoricalSession(
      date: lastSessionLogs.first.createdAt,
      targetReps: targetReps,
      completedReps: anyFailed ? targetReps - 1 : targetReps,
      load: maxLoad > 0 ? maxLoad : fallbackLoad,
      rpe: lastRpe ?? 8.0,
      failed: anyFailed,
    );

    final autoregResult = AutoregulationEngine.evaluate(
      exerciseName: lastSessionLogs.first.nodeTypeSlug,
      sessions: [historicalSession],
      loadIncrement: 2.5,
    );

    return ProgressionSuggestion(
      load: autoregResult.recommendedLoad,
      reps: targetReps,
      reasoning: autoregResult.reasoning,
      isProgressed: autoregResult.recommendedLoad > maxLoad,
    );
  }

  // ==========================================
  // WORKFLOW & SYNC QUEUE OPERATIONS
  // ==========================================

  /// Listens to all routines saved locally in SQLite in real time.
  Stream<List<Routine>> watchRoutines() {
    return (_db.select(_db.routinesTable)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Inserts or updates workflows received from server (Batch Upsert).
  Future<void> upsertWorkflows(List<Workflow> workflows) async {
    if (workflows.isEmpty) return;

    await _db.batch((batch) {
      for (final workflow in workflows) {
        batch.insert(
          _db.routinesTable,
          RoutinesTableCompanion.insert(
            id: Value(workflow.id),
            name: workflow.name,
            description: Value(workflow.description),
            blockCount: Value(workflow.blockCount),
            isPublic: Value(workflow.isPublic),
            updatedAt: workflow.updatedAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Removes routines from SQLite that were deleted on the server.
  Future<void> deleteWorkflows(List<int> ids) async {
    if (ids.isEmpty) return;

    await (_db.delete(_db.routinesTable)
          ..where((t) => t.id.isIn(ids)))
        .go();
  }

  /// Atomically purges confirmed mutations from the sync queue.
  Future<void> deleteQueueItemsByClientIds(List<String> clientIds) async {
    if (clientIds.isEmpty) return;

    await (_db.delete(_db.syncQueueTable)
          ..where((t) => t.entityClientId.isIn(clientIds)))
        .go();
  }
}

