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

  test('getSuggestedProgressionForBlock calcula sobrecarga progressiva (+2.5 kg) apos sessao anterior concluida', () async {
    // 1. Sessão 1 finalizada com 105 kg x 5 reps @ RPE 8.0
    await repository.startSession(
      clientId: 'sess-prev',
      workflowId: 1,
      sectionId: 'sec_1',
      sectionTitle: 'Treino A',
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

    // 2. Consulta sugestão para o próximo treino (nenhuma sessão ativa)
    final suggestion = await repository.getSuggestedProgressionForBlock('blk_squat');

    // Meta alcançada com RPE submáximo (8.0): 105.0 + 2.5 = 107.5 kg!
    expect(suggestion.load, equals(107.5));
    expect(suggestion.reps, equals(5));
    expect(suggestion.isProgressed, isTrue);
    expect(suggestion.reasoning, contains('107.5 kg'));
  });

  test('getSuggestedProgressionForBlock mantem a carga da serie anterior dentro da mesma sessao ativa', () async {
    // 1. Sessão ativa atual
    await repository.startSession(
      clientId: 'sess-now',
      workflowId: 1,
      sectionId: 'sec_1',
      sectionTitle: 'Treino A',
      startedAt: DateTime.utc(2026, 10, 7, 10),
    );

    // 2. Registra série 1 com 110 kg
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

    // 3. Consulta sugestão para a série 2
    final suggestion = await repository.getSuggestedProgressionForBlock('blk_squat');

    // Deve herdar 110.0 kg da série 1 (não voltar para 100 kg!)
    expect(suggestion.load, equals(110.0));
    expect(suggestion.reps, equals(5));
    expect(suggestion.isProgressed, isFalse);
    expect(suggestion.reasoning, contains('Mantendo carga da série anterior'));
  });
}
