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
  // STREAMS REATIVAS (A UI escuta em tempo real)
  // ==========================================

  /// Escuta a sessão de treino ativa no momento.
  /// Se o usuário fechar o app e reabrir, a UI restaura o estado instantaneamente.
  Stream<WorkoutSessionData?> watchActiveSession() {
    return (_db.select(_db.workoutSessionsTable)
          ..where((t) => t.status.equals('active'))
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Escuta todas as séries executadas em uma sessão específica, em ordem de criação.
  Stream<List<WorkoutSetLogData>> watchSessionLogs(String sessionClientId) {
    return (_db.select(_db.workoutSetLogsTable)
          ..where((t) => t.sessionClientId.equals(sessionClientId))
          ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
        .watch();
  }

  /// Escuta a quantidade de mutações pendentes na fila de sincronização.
  /// A UI usa isso para mostrar o ícone de nuvem ("3 pendentes" ou "Sincronizado").
  Stream<int> watchPendingSyncCount() {
    final countExp = _db.syncQueueTable.id.count();
    final query = _db.selectOnly(_db.syncQueueTable)
      ..addColumns([countExp])
      ..where(_db.syncQueueTable.status.equals('pending'));

    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  /// Retorna stream com todos os itens da fila outbox para inspeção e diagnóstico.
  Stream<List<SyncQueueData>> watchSyncQueue() {
    return (_db.select(_db.syncQueueTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  // ==========================================
  // OPERAÇÕES ATÔMICAS (Gravação Local + Outbox)
  // ==========================================

  /// Inicia uma nova sessão de treino e enfileira para sincronização.
  Future<WorkoutSessionData> startSession({
    required String clientId,
    required int workflowId,
    required String sectionId,
    required String sectionTitle,
    required DateTime startedAt,
  }) async {
    return _db.transaction(() async {
      // 1. Grava a sessão localmente no SQLite
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

      // 2. Grava a mutação na fila Outbox (sync_queue)
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

  /// Registra uma série concluída e enfileira para sincronização.
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
      // 1. Salva a série no SQLite local
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

      // 2. Enfileira mutação atômica na sync_queue
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

  /// Finaliza a sessão ativa.
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

  /// Calcula dinamicamente a carga e repetições sugeridas para o próximo set do bloco,
  /// integrando o histórico local do SQLite com o AutoregulationEngine da repengine_core.
  Future<ProgressionSuggestion> getSuggestedProgressionForBlock(
    String blockClientId, {
    double fallbackLoad = 100.0,
    int fallbackReps = 5,
  }) async {
    // 1. Verifica se já existem séries concluídas nesta sessão ativa
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
          reasoning: 'Mantendo carga da série anterior (#${lastSet.setIndex})',
          isProgressed: false,
        );
      }
    }

    // 2. Se for o início do treino (sem séries ainda), consulta histórico de sessões finalizadas
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
        reasoning: 'Carga inicial recomendada',
        isProgressed: false,
      );
    }

    // Agrupa as séries da sessão concluída mais recente
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
}
