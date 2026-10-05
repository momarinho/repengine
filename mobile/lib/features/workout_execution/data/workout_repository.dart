import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

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
}
