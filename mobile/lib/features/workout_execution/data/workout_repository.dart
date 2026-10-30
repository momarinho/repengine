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
  final double? loadB;
  final int? repsB;
  final String? displayText;

  const ProgressionSuggestion({
    required this.load,
    required this.reps,
    this.reasoning,
    this.isProgressed = false,
    this.loadB,
    this.repsB,
    this.displayText,
  });

  /// Formatted representation for display in HUD (e.g. "0 / 35 kg" or "100 kg")
  String get formattedLoad {
    if (displayText != null && displayText!.isNotEmpty) return displayText!;
    if (loadB != null) {
      final strA = load % 1 == 0 ? load.toInt().toString() : load.toStringAsFixed(1);
      final strB = loadB! % 1 == 0 ? loadB!.toInt().toString() : loadB!.toStringAsFixed(1);
      return '$strA / $strB kg';
    }
    final str = load % 1 == 0 ? load.toInt().toString() : load.toStringAsFixed(1);
    return '$str kg';
  }
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

  double _parseLoadValue(String? raw, double fallback, {int partIndex = 0}) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    if (raw.contains('/')) {
      final parts = raw.split('/');
      final part = (partIndex >= 0 && partIndex < parts.length)
          ? parts[partIndex]
          : parts.first;
      final cleanedPart = part.replaceAll(RegExp(r'[^\d.]'), '').trim();
      return double.tryParse(cleanedPart) ?? fallback;
    }
    final cleaned = raw.replaceAll(RegExp(r'[^\d.]'), '').trim();
    return double.tryParse(cleaned) ?? fallback;
  }

  /// Dynamically computes recommended load and repetitions for the next set in the block,
  /// strictly scoped to the active Day/Section to isolate progression curves across workout days.
  Future<ProgressionSuggestion> getSuggestedProgressionForBlock(
    String blockClientId, {
    String? sectionId,
    String? sectionTitle,
    double fallbackLoad = 100.0,
    int fallbackReps = 5,
    double loadIncrement = 2.5,
    String? progressionType,
    int? minReps,
    int? maxReps,
  }) async {
    final effectiveTargetReps = (progressionType == 'double' && minReps != null && minReps > 0)
        ? minReps
        : fallbackReps;

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
        final rawActual = lastSet.actualLoad;
        final isSuperset = rawActual.contains('/');
        final load = _parseLoadValue(rawActual, fallbackLoad, partIndex: 0);
        final loadB = isSuperset ? _parseLoadValue(rawActual, 0.0, partIndex: 1) : null;
        final reps = int.tryParse(lastSet.actualReps.split('/').first.trim()) ?? effectiveTargetReps;
        final repsB = isSuperset && lastSet.actualReps.contains('/')
            ? int.tryParse(lastSet.actualReps.split('/')[1].trim())
            : null;
        return ProgressionSuggestion(
          load: load,
          loadB: loadB,
          reps: reps,
          repsB: repsB,
          reasoning: 'Maintaining load from previous set (#${lastSet.setIndex})',
          isProgressed: false,
          displayText: isSuperset ? rawActual : null,
        );
      }
    }

    // 2. Query historical completed sessions STRICTLY SCOPED to this Day / Section
    final effectiveSectionId = sectionId ?? activeSession?.sectionId;
    final effectiveSectionTitle = sectionTitle ?? activeSession?.sectionTitle;

    List<WorkoutSetLogData> lastSessionLogs = [];

    if ((effectiveSectionId != null && effectiveSectionId.isNotEmpty) ||
        (effectiveSectionTitle != null && effectiveSectionTitle.isNotEmpty)) {
      final pastSessionsQuery = _db.select(_db.workoutSessionsTable)
        ..where((s) {
          var expr = s.status.isNotValue('active');
          if (activeSession != null) {
            expr = expr & s.clientId.isNotValue(activeSession.clientId);
          }
          if (effectiveSectionId != null && effectiveSectionId.isNotEmpty) {
            expr = expr &
                (s.sectionId.equals(effectiveSectionId) |
                    (effectiveSectionTitle != null && effectiveSectionTitle.isNotEmpty
                        ? s.sectionTitle.equals(effectiveSectionTitle)
                        : const Constant(false)));
          } else if (effectiveSectionTitle != null && effectiveSectionTitle.isNotEmpty) {
            expr = expr & s.sectionTitle.equals(effectiveSectionTitle);
          }
          return expr;
        })
        ..orderBy([(s) => OrderingTerm.desc(s.startedAt), (s) => OrderingTerm.desc(s.id)]);

      final pastSessions = await pastSessionsQuery.get();

      for (final pastSession in pastSessions) {
        final sessionLogs = await (_db.select(_db.workoutSetLogsTable)
              ..where((t) =>
                  t.sessionClientId.equals(pastSession.clientId) &
                  t.blockClientId.equals(blockClientId) &
                  t.completed.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
            .get();
        if (sessionLogs.isNotEmpty) {
          lastSessionLogs = sessionLogs;
          break; // Found the most recent matching Day/Section session
        }
      }
    } else {
      // Fallback for tests or workflows with unsectioned logs
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

      if (pastLogs.isNotEmpty) {
        final lastSessionClientId = pastLogs.first.sessionClientId;
        lastSessionLogs = pastLogs
            .where((l) => l.sessionClientId == lastSessionClientId)
            .toList();
      }
    }

    // 3. If no historical logs found for this Day/Section, check progression state or fallback
    if (lastSessionLogs.isEmpty) {
      final progressionState = await getProgressionStateForBlock(blockClientId);
      if (progressionState != null && progressionState.suggestedLoad != null) {
        final rawSugLoad = progressionState.suggestedLoad!;
        final isSuperset = rawSugLoad.contains('/');
        final syncedLoad = _parseLoadValue(rawSugLoad, fallbackLoad, partIndex: 0);
        final syncedLoadB = isSuperset ? _parseLoadValue(rawSugLoad, 0.0, partIndex: 1) : null;
        return ProgressionSuggestion(
          load: syncedLoad,
          loadB: syncedLoadB,
          reps: effectiveTargetReps,
          reasoning: progressionState.summary ?? 'Prescribed target load from coach',
          isProgressed: false,
          displayText: isSuperset ? rawSugLoad : null,
        );
      }

      return ProgressionSuggestion(
        load: fallbackLoad,
        reps: effectiveTargetReps,
        reasoning: progressionType == 'double'
            ? 'Starting double progression at target minimum ($effectiveTargetReps reps)'
            : 'Initial recommended load',
        isProgressed: false,
      );
    }

    // 4. Calculate progressive overload from previous session of THIS Day/Section
    double maxLoad = 0.0;
    int targetReps = effectiveTargetReps;
    double? lastRpe;
    bool anyFailed = false;

    for (final log in lastSessionLogs) {
      final load = _parseLoadValue(log.actualLoad, 0.0);
      if (load > maxLoad) maxLoad = load;
      final reps = int.tryParse(log.actualReps) ?? 0;
      final prescribed = int.tryParse(log.prescribedReps) ?? effectiveTargetReps;
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

    // Double progression handling
    if (progressionType == 'double' && minReps != null && maxReps != null) {
      if (!anyFailed && targetReps >= maxReps) {
        final newLoad = (maxLoad > 0 ? maxLoad : fallbackLoad) + loadIncrement;
        return ProgressionSuggestion(
          load: newLoad,
          reps: minReps,
          reasoning: 'Reached maximum reps ($maxReps). Increasing load by $loadIncrement kg and resetting to $minReps reps.',
          isProgressed: true,
        );
      } else if (!anyFailed) {
        final nextReps = (targetReps < maxReps) ? targetReps + 1 : targetReps;
        return ProgressionSuggestion(
          load: maxLoad > 0 ? maxLoad : fallbackLoad,
          reps: nextReps,
          reasoning: 'Target hit! Maintain load and aim for $nextReps reps next time (range: $minReps-$maxReps).',
          isProgressed: nextReps > targetReps,
        );
      } else {
        return ProgressionSuggestion(
          load: maxLoad > 0 ? maxLoad : fallbackLoad,
          reps: targetReps,
          reasoning: 'Target missed. Keep load and retry $targetReps reps.',
          isProgressed: false,
        );
      }
    }

    final autoregResult = AutoregulationEngine.evaluate(
      exerciseName: lastSessionLogs.first.nodeTypeSlug,
      sessions: [historicalSession],
      loadIncrement: loadIncrement,
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

  /// Retrieves the current progression state for a block key or workflow block ID.
  Future<ProgressionStateRow?> getProgressionStateForBlock(String blockKeyOrId) async {
    final asInt = int.tryParse(blockKeyOrId);
    if (asInt != null) {
      final byBlockId = await (_db.select(_db.progressionStatesTable)
            ..where((t) => t.workflowBlockId.equals(asInt) | t.blockKey.equals(blockKeyOrId))
            ..limit(1))
          .getSingleOrNull();
      if (byBlockId != null) return byBlockId;
    }
    return (_db.select(_db.progressionStatesTable)
          ..where((t) => t.blockKey.equals(blockKeyOrId))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Reconciles completed workout sessions and set logs fetched from server sync.
  Future<void> upsertHistoricalSessions(List<WorkoutSession> sessions) async {
    if (sessions.isEmpty) return;

    await _db.transaction(() async {
      for (final session in sessions) {
        final sessionClientId = session.clientId != null && session.clientId!.isNotEmpty
            ? session.clientId!
            : 'sess_server_${session.id}';

        final existing = await (_db.select(_db.workoutSessionsTable)
              ..where((t) =>
                  t.clientId.equals(sessionClientId) |
                  (session.id != null ? t.serverId.equals(session.id!) : const Constant(false)))
              ..limit(1))
            .getSingleOrNull();

        if (existing == null) {
          await _db.into(_db.workoutSessionsTable).insert(
                WorkoutSessionsTableCompanion.insert(
                  clientId: sessionClientId,
                  serverId: Value(session.id),
                  workflowId: session.workflowId,
                  sectionId: session.sectionId,
                  sectionTitle: session.sectionTitle,
                  status: Value(session.status),
                  startedAt: session.startedAt,
                  completedAt: Value(session.completedAt),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        for (final log in session.logs) {
          final logClientId = log.clientId != null && log.clientId!.isNotEmpty
              ? log.clientId!
              : 'log_server_${log.id ?? '${session.id}_${log.setIndex}'}';

          final existingLog = await (_db.select(_db.workoutSetLogsTable)
                ..where((t) => t.clientId.equals(logClientId))
                ..limit(1))
              .getSingleOrNull();

          if (existingLog == null) {
            final effectiveBlockId = log.blockClientId.isNotEmpty
                ? log.blockClientId
                : (log.workflowBlockId?.toString() ?? '');

            await _db.into(_db.workoutSetLogsTable).insert(
                  WorkoutSetLogsTableCompanion.insert(
                    clientId: logClientId,
                    sessionClientId: existing?.clientId ?? sessionClientId,
                    serverId: Value(log.id),
                    blockClientId: effectiveBlockId,
                    nodeTypeSlug: log.nodeTypeSlug,
                    setIndex: log.setIndex,
                    prescribedReps: Value(log.prescribedReps),
                    prescribedLoad: Value(log.prescribedLoad),
                    actualReps: Value(log.actualReps),
                    actualLoad: Value(log.actualLoad),
                    actualRpe: Value(log.actualRpe),
                    completed: Value(log.completed),
                    createdAt: session.completedAt ?? session.startedAt,
                  ),
                  mode: InsertMode.insertOrReplace,
                );
          }
        }
      }
    });
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
          final newExerciseBlocks = updatedExercises.map((ex) {
            final dataMap = <String, dynamic>{
              'exercise_name': ex.name,
              'sets': ex.sets,
              'reps': ex.reps,
              'load': ex.targetLoad,
              'rest_seconds': ex.restSeconds,
            };
            if (ex.isSuperset) {
              if (ex.exerciseAName != null) dataMap['exercise_a_name'] = ex.exerciseAName;
              if (ex.exerciseBName != null) dataMap['exercise_b_name'] = ex.exerciseBName;
              if (ex.repsA != null) dataMap['reps_a'] = ex.repsA;
              if (ex.repsB != null) dataMap['reps_b'] = ex.repsB;
              if (ex.targetLoadA != null) dataMap['start_load_a'] = ex.targetLoadA;
              if (ex.targetLoadB != null) dataMap['start_load_b'] = ex.targetLoadB;
              if (ex.progressionTypeA != null) dataMap['progression_type_a'] = ex.progressionTypeA;
              if (ex.progressionTypeB != null) dataMap['progression_type_b'] = ex.progressionTypeB;
              if (ex.progressionIncrementA != null) dataMap['increment_a'] = ex.progressionIncrementA;
              if (ex.progressionIncrementB != null) dataMap['increment_b'] = ex.progressionIncrementB;
              if (ex.progressionMinRepsA != null) dataMap['min_reps_a'] = ex.progressionMinRepsA;
              if (ex.progressionMaxRepsA != null) dataMap['max_reps_a'] = ex.progressionMaxRepsA;
              if (ex.progressionMinRepsB != null) dataMap['min_reps_b'] = ex.progressionMinRepsB;
              if (ex.progressionMaxRepsB != null) dataMap['max_reps_b'] = ex.progressionMaxRepsB;
            }
            if (ex.progressionType != null) {
              dataMap['progression'] = {
                'type': ex.progressionType,
                if (ex.progressionIncrement != null) 'increment': ex.progressionIncrement,
                if (ex.progressionMinReps != null) 'min_reps': ex.progressionMinReps,
                if (ex.progressionMaxReps != null) 'max_reps': ex.progressionMaxReps,
                if (ex.progressionRule != null) 'rule': ex.progressionRule,
              };
            }
            return {
              'id': ex.blockClientId,
              'node_type_slug': ex.nodeTypeSlug,
              'data': dataMap,
            };
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
          final exerciseData = <String, dynamic>{
            'exercise_name': ex.name,
            'sets': ex.sets,
            'reps': ex.reps,
            'load': ex.targetLoad,
            'rest_seconds': ex.restSeconds,
          };
          if (ex.progressionType != null) {
            exerciseData['progression'] = {
              'type': ex.progressionType,
              if (ex.progressionIncrement != null) 'increment': ex.progressionIncrement,
              if (ex.progressionMinReps != null) 'min_reps': ex.progressionMinReps,
              if (ex.progressionMaxReps != null) 'max_reps': ex.progressionMaxReps,
              if (ex.progressionRule != null) 'rule': ex.progressionRule,
            };
          }
          blockList.add({
            'id': exId,
            'node_type_slug': ex.nodeTypeSlug.isNotEmpty ? ex.nodeTypeSlug : 'exercise_custom',
            'data': exerciseData,
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

