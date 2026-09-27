import 'package:repengine_core/repengine_core.dart';
import 'package:test/test.dart';

void main() {
  group('RepEngine Core Contracts', () {
    test('SyncPushPayload serialization round-trip', () {
      final now = DateTime.utc(2026, 9, 26, 12, 0);

      final payload = SyncPushPayload(
        sessions: [
          WorkoutSession(
            id: 1,
            workflowId: 10,
            userId: 42,
            sectionId: 'sec_legs',
            sectionTitle: 'Leg Day',
            status: 'completed',
            startedAt: now,
            completedAt: now.add(const Duration(minutes: 45)),
            notes: 'Felt great',
            logCount: 1,
            clientId: 'client-session-uuid-1',
          ),
        ],
        setLogs: [
          WorkoutSetLog(
            id: 101,
            sessionId: 1,
            blockClientId: 'block_squat',
            nodeTypeSlug: 'exercise_squat',
            setIndex: 0,
            prescribedReps: '5',
            prescribedLoad: '140kg',
            actualReps: '5',
            actualLoad: '140kg',
            completed: true,
            clientId: 'client-log-uuid-1',
            createdAt: now.add(const Duration(minutes: 10)),
          ),
        ],
      );

      final json = payload.toJson();
      final reconstructed = SyncPushPayload.fromJson(json);

      expect(reconstructed.sessions.length, equals(1));
      expect(
        reconstructed.sessions.first.clientId,
        equals('client-session-uuid-1'),
      );
      expect(reconstructed.setLogs.first.actualLoad, equals('140kg'));
      expect(reconstructed.setLogs.first.completed, isTrue);
    });

    test('SyncPushResult serialization with enum matching', () {
      final result = SyncPushResult(
        items: const [
          SyncPushItemStatus(
            clientId: 'client-session-uuid-1',
            status: SyncItemStatus.accepted,
            serverId: 1,
          ),
          SyncPushItemStatus(
            clientId: 'client-log-uuid-duplicate',
            status: SyncItemStatus.ignoredDuplicate,
            message: 'Already processed',
          ),
        ],
        processedAt: DateTime.utc(2026, 9, 26, 12, 1),
      );

      final json = result.toJson();
      final reconstructed = SyncPushResult.fromJson(json);

      expect(reconstructed.items.length, equals(2));
      expect(reconstructed.items[0].status, equals(SyncItemStatus.accepted));
      expect(reconstructed.items[0].serverId, equals(1));
      expect(
        reconstructed.items[1].status,
        equals(SyncItemStatus.ignoredDuplicate),
      );
    });

    test('SyncPullResponse delta sync with deleted routines', () {
      final response = SyncPullResponse(
        updatedWorkflows: [
          Workflow(
            id: 10,
            userId: 42,
            name: 'PPL - Push A',
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 26, 11, 0),
          ),
        ],
        deletedWorkflowIds: [5, 8],
        serverTimestamp: DateTime.utc(2026, 9, 26, 12, 0),
      );

      final json = response.toJson();
      final reconstructed = SyncPullResponse.fromJson(json);

      expect(reconstructed.updatedWorkflows.length, equals(1));
      expect(reconstructed.updatedWorkflows.first.name, equals('PPL - Push A'));
      expect(reconstructed.deletedWorkflowIds, equals([5, 8]));
    });
  });
}
