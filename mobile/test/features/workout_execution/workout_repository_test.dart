import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('startSession grava sessao e enfileira mutacao atomicamente na outbox', () async {
    final session = await repository.startSession(
      clientId: 'sess-100',
      workflowId: 2,
      sectionId: 'sec_a',
      sectionTitle: 'Treino A',
      startedAt: DateTime.utc(2026, 10, 3, 14),
    );

    expect(session.clientId, equals('sess-100'));
    expect(session.status, equals('active'));

    // Verifica se a outbox recebeu o item
    final queue = await db.select(db.syncQueueTable).get();
    expect(queue, hasLength(1));
    expect(queue.first.entityClientId, equals('sess-100'));
    expect(queue.first.action, equals('CREATE'));
  });

  test('watchActiveSession e watchSessionLogs emitem atualizacoes em tempo real', () async {
    // 1. Inicia treino
    await repository.startSession(
      clientId: 'sess-200',
      workflowId: 1,
      sectionId: 'sec_b',
      sectionTitle: 'Treino B',
      startedAt: DateTime.utc(2026, 10, 3, 15),
    );

    // 2. Registra série
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

    // 3. Testa streams
    final active = await repository.watchActiveSession().first;
    expect(active?.clientId, equals('sess-200'));

    final logs = await repository.watchSessionLogs('sess-200').first;
    expect(logs, hasLength(1));
    expect(logs.first.actualLoad, equals('102.5'));

    final pending = await repository.watchPendingSyncCount().first;
    expect(pending, equals(2)); // 1 sessão + 1 série
  });

  test('completeSession atualiza status e adiciona mutacao UPDATE na outbox', () async {
    await repository.startSession(
      clientId: 'sess-300',
      workflowId: 1,
      sectionId: 'sec_c',
      sectionTitle: 'Treino C',
      startedAt: DateTime.utc(2026, 10, 3, 16),
    );

    await repository.completeSession('sess-300');

    final active = await repository.watchActiveSession().first;
    expect(active, isNull);

    final queue = await db.select(db.syncQueueTable).get();
    expect(queue, hasLength(2)); // 1 CREATE + 1 UPDATE
    expect(queue.last.action, equals('UPDATE'));
  });
}
