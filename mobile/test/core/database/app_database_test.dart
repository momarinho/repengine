import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_mobile/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('can insert and query routines from local database', () async {
    final routine = RoutinesTableCompanion.insert(
      id: const Value(1),
      name: 'GZCLP Hybrid',
      description: const Value('4-day strength program'),
      updatedAt: DateTime.utc(2026, 10, 3),
    );
    await db.into(db.routinesTable).insert(routine);

    final all = await db.select(db.routinesTable).get();
    expect(all, hasLength(1));
    expect(all.first.name, equals('GZCLP Hybrid'));
  });

  test('can insert session and set logs with client_id', () async {
    await db.into(db.workoutSessionsTable).insert(
      WorkoutSessionsTableCompanion.insert(
        clientId: 'sess-uuid-1',
        workflowId: 1,
        sectionId: 'sec_1',
        sectionTitle: 'Day 1',
        startedAt: DateTime.utc(2026, 10, 3, 10),
      ),
    );

    final sessions = await db.select(db.workoutSessionsTable).get();
    expect(sessions, hasLength(1));
    expect(sessions.first.clientId, equals('sess-uuid-1'));
  });

  test('can queue mutations in sync_queue for Outbox pattern', () async {
    await db.into(db.syncQueueTable).insert(
      SyncQueueTableCompanion.insert(
        entityClientId: 'sess-uuid-1',
        entityType: 'session',
        action: 'CREATE',
        payload: '{"workflow_id":1,"client_id":"sess-uuid-1"}',
        createdAt: DateTime.utc(2026, 10, 3, 10),
      ),
    );

    final queue = await db.select(db.syncQueueTable).get();
    expect(queue, hasLength(1));
    expect(queue.first.entityClientId, equals('sess-uuid-1'));
    expect(queue.first.status, equals('pending'));
  });
}
