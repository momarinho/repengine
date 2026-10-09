import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repengine_core/repengine_core.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/routine_model.dart';

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

  /// Listens to all completed workout sessions ordered by startedAt DESC.
  Stream<List<WorkoutSessionData>> watchCompletedSessions() {
    return (_db.select(_db.workoutSessionsTable)
          ..where((t) => t.status.equals('completed'))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  /// Retrieves all set logs for a given session.
  Future<List<WorkoutSetLogData>> getSessionLogs(String sessionClientId) {
    return (_db.select(_db.workoutSetLogsTable)
          ..where((t) => t.sessionClientId.equals(sessionClientId))
          ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
        .get();
  }

  /// Deletes a completed session and its associated logs from local storage.
  Future<void> deleteCompletedSession(String sessionClientId) {
    return abandonSession(sessionClientId, deleteSession: true);
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
  Future<void> completeSession(String sessionClientId, {DateTime? completedAt}) async {
    await _db.transaction(() async {
      final now = completedAt?.toUtc() ?? DateTime.now().toUtc();

      await (_db.update(_db.workoutSessionsTable)
            ..where((t) => t.clientId.equals(sessionClientId)))
          .write(
        WorkoutSessionsTableCompanion(
          status: const Value('completed'),
          completedAt: Value(now),
        ),
      );

      final existing = await (_db.select(_db.workoutSessionsTable)
            ..where((t) => t.clientId.equals(sessionClientId)))
          .getSingleOrNull();

      await _db.into(_db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              entityClientId: sessionClientId,
              entityType: 'session',
              action: 'UPDATE',
              payload: jsonEncode({
                'client_id': sessionClientId,
                'workflow_id': existing?.workflowId ?? 0,
                'section_id': existing?.sectionId ?? '',
                'section_title': existing?.sectionTitle ?? '',
                'status': 'completed',
                'started_at': existing?.startedAt.toUtc().toIso8601String() ?? now.toIso8601String(),
                'completed_at': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });
  }

  /// Abandons an active workout session.
  ///
  /// Discards all logged sets for this session, cleans pending mutations
  /// from the sync outbox ([SyncQueueTable]) so incomplete data is never sent to the backend,
  /// and deletes the session row from SQLite (or marks as 'abandoned' if [deleteSession] is false).
  Future<void> abandonSession(String sessionClientId, {bool deleteSession = true}) async {
    await _db.transaction(() async {
      // 1. Collect all set log client IDs belonging to this session
      final sessionSets = await (_db.select(_db.workoutSetLogsTable)
            ..where((t) => t.sessionClientId.equals(sessionClientId)))
          .get();
      final setClientIds = sessionSets.map((s) => s.clientId).toList();

      // 2. Remove pending mutations for this session and its set logs from sync_queue
      final clientIdsToRemove = [sessionClientId, ...setClientIds];
      await (_db.delete(_db.syncQueueTable)
            ..where((t) => t.entityClientId.isIn(clientIdsToRemove)))
          .go();

      // 3. Purge all set logs for this session
      await (_db.delete(_db.workoutSetLogsTable)
            ..where((t) => t.sessionClientId.equals(sessionClientId)))
          .go();

      // 4. Delete the session or mark as abandoned
      if (deleteSession) {
        await (_db.delete(_db.workoutSessionsTable)
              ..where((t) => t.clientId.equals(sessionClientId)))
            .go();
      } else {
        await (_db.update(_db.workoutSessionsTable)
              ..where((t) => t.clientId.equals(sessionClientId)))
            .write(
          WorkoutSessionsTableCompanion(
            status: const Value('abandoned'),
            completedAt: Value(DateTime.now().toUtc()),
          ),
        );
      }
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
      final progressionState = await getProgressionStateForBlock(blockClientId);
      if (progressionState != null && progressionState.suggestedLoad != null) {
        final syncedLoad = double.tryParse(progressionState.suggestedLoad!) ?? fallbackLoad;
        return ProgressionSuggestion(
          load: syncedLoad,
          reps: fallbackReps,
          reasoning: progressionState.summary ?? 'Prescribed target load from coach',
          isProgressed: false,
        );
      }

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
        final blocksJson = jsonEncode(workflow.blocks.map((b) => b.toJson()).toList());
        batch.insert(
          _db.routinesTable,
          RoutinesTableCompanion.insert(
            id: Value(workflow.id),
            name: workflow.name,
            description: Value(workflow.description),
            blockCount: Value(workflow.blockCount),
            isPublic: Value(workflow.isPublic),
            updatedAt: workflow.updatedAt,
            blocksJson: Value(blocksJson),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Retrieves a routine by ID from local SQLite.
  Future<Routine?> getRoutineById(int id) {
    return (_db.select(_db.routinesTable)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Removes routines from SQLite that were deleted on the server.
  Future<void> deleteWorkflows(List<int> ids) async {
    if (ids.isEmpty) return;

    await (_db.delete(_db.routinesTable)
          ..where((t) => t.id.isIn(ids)))
        .go();
  }

  /// Reconciles local routines with the full list of active workflows from server.
  /// Removes any routine no longer present on server and upserts all active ones.
  Future<void> reconcileWorkflows(List<Workflow> workflows) async {
    final activeIds = workflows.map((w) => w.id).toSet();
    if (activeIds.isNotEmpty) {
      await (_db.delete(_db.routinesTable)
            ..where((t) => t.id.isNotIn(activeIds)))
          .go();
    } else {
      await _db.delete(_db.routinesTable).go();
    }

    if (workflows.isNotEmpty) {
      await upsertWorkflows(workflows);
    }
  }

  /// Clears all stored routines from SQLite.
  Future<void> clearRoutines() async {
    await _db.delete(_db.routinesTable).go();
  }

  /// Atomically purges confirmed mutations from the sync queue.
  Future<void> deleteQueueItemsByClientIds(List<String> clientIds) async {
    if (clientIds.isEmpty) return;

    await (_db.delete(_db.syncQueueTable)
          ..where((t) => t.entityClientId.isIn(clientIds)))
        .go();
  }

  // ==========================================
  // PROGRESSION STATES (Offline Continuity)
  // ==========================================

  /// Inserts or updates progression states received from server.
  Future<void> upsertProgressionStates(List<ProgressionState> states) async {
    if (states.isEmpty) return;

    await _db.batch((batch) {
      for (final state in states) {
        batch.insert(
          _db.progressionStatesTable,
          ProgressionStatesTableCompanion.insert(
            id: Value(state.id),
            workflowId: state.workflowId,
            workflowBlockId: Value(state.workflowBlockId),
            blockKey: state.blockKey,
            nodeTypeSlug: state.nodeTypeSlug,
            stateType: state.stateType,
            exerciseName: Value(state.exerciseName),
            outcome: state.outcome,
            currentLoad: Value(state.currentLoad),
            suggestedLoad: Value(state.suggestedLoad),
            currentWeek: Value(state.currentWeek),
            suggestedWeek: Value(state.suggestedWeek),
            summary: Value(state.summary),
            updatedAt: state.updatedAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Listens to all progression states for a workflow in SQLite.
  Stream<List<ProgressionStateRow>> watchProgressionStates(int workflowId) {
    return (_db.select(_db.progressionStatesTable)
          ..where((t) => t.workflowId.equals(workflowId))
          ..orderBy([(t) => OrderingTerm.asc(t.blockKey)]))
        .watch();
  }

  /// Retrieves the current progression state for a block key.
  Future<ProgressionStateRow?> getProgressionStateForBlock(String blockKey) {
    return (_db.select(_db.progressionStatesTable)
          ..where((t) => t.blockKey.equals(blockKey))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Updates the template blocks of a routine in local SQLite with modified exercises and loads.
  /// Also enqueues an UPDATE mutation in the sync queue for cloud replication.
  Future<void> updateRoutineSectionExercises({
    required int routineId,
    required String sectionId,
    required List<RoutineExercise> updatedExercises,
  }) async {
    await _db.transaction(() async {
      final routine = await (_db.select(_db.routinesTable)
            ..where((t) => t.id.equals(routineId))
            ..limit(1))
          .getSingleOrNull();

      if (routine == null) return;

      List<dynamic> blockList = [];
      try {
        if (routine.blocksJson.isNotEmpty && routine.blocksJson != '[]') {
          blockList = jsonDecode(routine.blocksJson) as List<dynamic>;
        }
      } catch (_) {
        blockList = [];
      }

      // If routine had default/empty blocks, construct from ParsedRoutine
      if (blockList.isEmpty) {
        final parsed = ParsedRoutine.fromRoutine(routine);
        final reconstructedBlocks = <Map<String, dynamic>>[];
        for (final sec in parsed.sections) {
          reconstructedBlocks.add({
            'id': sec.id,
            'node_type_slug': 'section',
            'data': {'title': sec.title, 'subtitle': sec.subtitle},
          });
          final exercisesToUse = sec.id == sectionId ? updatedExercises : sec.exercises;
          for (final ex in exercisesToUse) {
            reconstructedBlocks.add({
              'id': ex.blockClientId,
              'node_type_slug': ex.nodeTypeSlug,
              'data': {
                'exercise_name': ex.name,
                'sets': ex.sets,
                'reps': ex.reps,
                'load': ex.targetLoad,
                'rest_seconds': ex.restSeconds,
              },
            });
          }
        }
        blockList = reconstructedBlocks;
      } else {
        // Find existing section block index
        int sectionIndex = -1;
        for (var i = 0; i < blockList.length; i++) {
          final b = blockList[i] as Map<String, dynamic>;
          if (b['id']?.toString() == sectionId ||
              (b['node_type_slug'] == 'section' && b['id']?.toString() == sectionId)) {
            sectionIndex = i;
            break;
          }
        }

        if (sectionIndex != -1) {
          // Find boundary of next section
          int nextSectionIndex = blockList.length;
          for (var i = sectionIndex + 1; i < blockList.length; i++) {
            final b = blockList[i] as Map<String, dynamic>;
            if (b['node_type_slug'] == 'section') {
              nextSectionIndex = i;
              break;
            }
          }

          // Build new exercise blocks for this section
          final newExerciseBlocks = updatedExercises.map((ex) => {
            'id': ex.blockClientId,
            'node_type_slug': ex.nodeTypeSlug,
            'data': {
              'exercise_name': ex.name,
              'sets': ex.sets,
              'reps': ex.reps,
              'load': ex.targetLoad,
              'rest_seconds': ex.restSeconds,
            },
          }).toList();

          // Replace old exercises in that section slice
          final beforeSection = blockList.sublist(0, sectionIndex + 1);
          final afterSection = blockList.sublist(nextSectionIndex);
          blockList = [...beforeSection, ...newExerciseBlocks, ...afterSection];
        }
      }

      final newBlocksJson = jsonEncode(blockList);
      final now = DateTime.now().toUtc();

      await (_db.update(_db.routinesTable)
            ..where((t) => t.id.equals(routineId)))
          .write(
        RoutinesTableCompanion(
          blocksJson: Value(newBlocksJson),
          updatedAt: Value(now),
        ),
      );

      // Enqueue sync mutation
      await _db.into(_db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              entityClientId: 'routine-$routineId',
              entityType: 'workflow',
              action: 'UPDATE',
              payload: jsonEncode({
                'id': routineId,
                'blocks_json': newBlocksJson,
                'updated_at': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });
  }

  /// Creates a new custom routine locally and enqueues it for sync.
  Future<Routine> createRoutine({
    required String name,
    String description = '',
    required List<RoutineSection> sections,
  }) async {
    return _db.transaction(() async {
      final now = DateTime.now().toUtc();

      // Determine unique local ID
      final existingRoutines = await _db.select(_db.routinesTable).get();
      int newId = 101;
      if (existingRoutines.isNotEmpty) {
        final maxId = existingRoutines.map((r) => r.id).reduce((a, b) => a > b ? a : b);
        newId = maxId + 1;
      }

      final blockList = <Map<String, dynamic>>[];
      int blockIndex = 1;
      for (final sec in sections) {
        final secId = sec.id.isNotEmpty ? sec.id : 'sec_${newId}_$blockIndex';
        blockList.add({
          'id': secId,
          'node_type_slug': 'section',
          'data': {
            'title': sec.title,
            'subtitle': sec.subtitle,
          },
        });
        blockIndex++;
        for (final ex in sec.exercises) {
          final exId = ex.blockClientId.isNotEmpty ? ex.blockClientId : 'blk_${newId}_$blockIndex';
          blockList.add({
            'id': exId,
            'node_type_slug': ex.nodeTypeSlug.isNotEmpty ? ex.nodeTypeSlug : 'exercise_custom',
            'data': {
              'exercise_name': ex.name,
              'sets': ex.sets,
              'reps': ex.reps,
              'load': ex.targetLoad,
              'rest_seconds': ex.restSeconds,
            },
          });
          blockIndex++;
        }
      }

      final blocksJson = jsonEncode(blockList);

      await _db.into(_db.routinesTable).insert(
            RoutinesTableCompanion.insert(
              id: Value(newId),
              name: name,
              description: Value(description),
              blockCount: Value(blockList.length),
              isPublic: const Value(false),
              updatedAt: now,
              blocksJson: Value(blocksJson),
            ),
          );

      await _db.into(_db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              entityClientId: 'routine-$newId',
              entityType: 'workflow',
              action: 'CREATE',
              payload: jsonEncode({
                'id': newId,
                'name': name,
                'description': description,
                'blocks_json': blocksJson,
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );

      return (_db.select(_db.routinesTable)..where((t) => t.id.equals(newId))).getSingle();
    });
  }

  /// Updates an existing routine locally and enqueues it for sync.
  Future<void> updateRoutine({
    required int id,
    required String name,
    String description = '',
    required List<RoutineSection> sections,
  }) async {
    await _db.transaction(() async {
      final now = DateTime.now().toUtc();

      final blockList = <Map<String, dynamic>>[];
      int blockIndex = 1;
      for (final sec in sections) {
        final secId = sec.id.isNotEmpty ? sec.id : 'sec_${id}_$blockIndex';
        blockList.add({
          'id': secId,
          'node_type_slug': 'section',
          'data': {
            'title': sec.title,
            'subtitle': sec.subtitle,
          },
        });
        blockIndex++;
        for (final ex in sec.exercises) {
          final exId = ex.blockClientId.isNotEmpty ? ex.blockClientId : 'blk_${id}_$blockIndex';
          blockList.add({
            'id': exId,
            'node_type_slug': ex.nodeTypeSlug.isNotEmpty ? ex.nodeTypeSlug : 'exercise_custom',
            'data': {
              'exercise_name': ex.name,
              'sets': ex.sets,
              'reps': ex.reps,
              'load': ex.targetLoad,
              'rest_seconds': ex.restSeconds,
            },
          });
          blockIndex++;
        }
      }

      final blocksJson = jsonEncode(blockList);

      await (_db.update(_db.routinesTable)..where((t) => t.id.equals(id))).write(
        RoutinesTableCompanion(
          name: Value(name),
          description: Value(description),
          blockCount: Value(blockList.length),
          blocksJson: Value(blocksJson),
          updatedAt: Value(now),
        ),
      );

      await _db.into(_db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              entityClientId: 'routine-$id',
              entityType: 'workflow',
              action: 'UPDATE',
              payload: jsonEncode({
                'id': id,
                'name': name,
                'description': description,
                'blocks_json': blocksJson,
                'updated_at': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });
  }

  /// Deletes a routine locally and enqueues deletion for sync.
  Future<void> deleteRoutine(int id) async {
    await _db.transaction(() async {
      final now = DateTime.now().toUtc();

      await (_db.delete(_db.routinesTable)..where((t) => t.id.equals(id))).go();

      await _db.into(_db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              entityClientId: 'routine-$id',
              entityType: 'workflow',
              action: 'DELETE',
              payload: jsonEncode({
                'id': id,
                'deleted_at': now.toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });
  }
}

