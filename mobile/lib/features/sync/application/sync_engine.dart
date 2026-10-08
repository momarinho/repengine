import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/server_config.dart';
import '../../workout_execution/data/workout_repository.dart';
import '../data/sync_http_client.dart';

/// Status of the synchronization engine.
enum SyncStatus { idle, syncing, success, error }

/// Immutable state emitted by the SyncEngine.
@immutable
class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSyncedAt;

  const SyncState({
    this.status = SyncStatus.idle,
    this.errorMessage,
    this.lastSyncedAt,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? errorMessage,
    DateTime? lastSyncedAt,
  }) {
    return SyncState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

/// Orchestrates two-phase synchronization between local SQLite (Drift)
/// and the Dart Frog BFF.
///
/// Phase 1 (Push): Empties local Outbox (SyncQueueTable) sending batches to POST /sync/push.
/// Phase 2 (Pull): Fetches delta updates from GET /sync/pull and upserts workflows into SQLite.
class SyncEngine extends StateNotifier<SyncState> {
  static const _lastSyncedKey = 'repengine_last_synced_at';

  final SyncHttpClient httpClient;
  final WorkoutRepository repository;
  final AppDatabase db;
  SharedPreferences? prefs;

  SyncEngine({
    required this.httpClient,
    required this.repository,
    required this.db,
    this.prefs,
  }) : super(const SyncState()) {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    prefs ??= await SharedPreferences.getInstance();
    final saved = prefs?.getString(_lastSyncedKey);
    if (saved != null) {
      final parsed = DateTime.tryParse(saved);
      if (parsed != null && mounted) {
        state = state.copyWith(lastSyncedAt: parsed);
      }
    }
  }

  /// Clears the cached sync timestamp, forcing the next sync to be a full pull.
  Future<void> clearSyncCache() async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs?.remove(_lastSyncedKey);
    state = state.copyWith(lastSyncedAt: null);
  }

  /// Triggers a 2-phase sync (Push mutations -> Pull workflows).
  ///
  /// When [forceFullSync] is true, ignores local timestamp cache and pulls
  /// all active workflows from scratch, reconciling any deleted or updated routines.
  Future<bool> syncNow({bool forceFullSync = false}) async {
    if (state.status == SyncStatus.syncing) {
      return false;
    }

    state = state.copyWith(status: SyncStatus.syncing, errorMessage: null);

    try {
      if (prefs == null) {
        await _initPrefs();
      }

      // ==========================================
      // PHASE 1: PUSH (Local Outbox -> Dart Frog BFF)
      // ==========================================
      final pendingQueue = await (db.select(db.syncQueueTable)
            ..where((t) => t.status.equals('pending')))
          .get();

      if (pendingQueue.isNotEmpty) {
        final sessions = <WorkoutSession>[];
        final setLogs = <WorkoutSetLog>[];

        for (final item in pendingQueue) {
          try {
            final jsonMap = jsonDecode(item.payload) as Map<String, dynamic>;
            if (item.entityType == 'session') {
              sessions.add(WorkoutSession.fromJson(jsonMap));
            } else if (item.entityType == 'set_log') {
              setLogs.add(WorkoutSetLog.fromJson(jsonMap));
            }
          } catch (e) {
            debugPrint('SyncEngine: Error parsing queue item ${item.id}: $e');
          }
        }

        if (sessions.isNotEmpty || setLogs.isNotEmpty) {
          final pushPayload = SyncPushPayload(
            sessions: sessions,
            setLogs: setLogs,
          );

          final pushResult = await httpClient.pushMutations(pushPayload);

          if (pushResult == null) {
            state = state.copyWith(
              status: SyncStatus.error,
              errorMessage: 'Failed to push mutations to server',
            );
            return false;
          }

          // Atomic purge: delete queue items confirmed by server
          final confirmedClientIds = pushResult.items
              .where((item) =>
                  item.status == SyncItemStatus.accepted ||
                  item.status == SyncItemStatus.ignoredDuplicate)
              .map((item) => item.clientId)
              .toList();

          await repository.deleteQueueItemsByClientIds(confirmedClientIds);
        }
      }

      // ==========================================
      // PHASE 2: PULL (Dart Frog BFF -> SQLite Workflows)
      // ==========================================
      DateTime? lastSyncDate;
      if (!forceFullSync) {
        final lastSyncIso = prefs?.getString(_lastSyncedKey);
        lastSyncDate =
            lastSyncIso != null ? DateTime.tryParse(lastSyncIso) : null;
      }

      final pullResponse =
          await httpClient.pullWorkflows(lastSyncedAt: lastSyncDate);

      if (pullResponse != null) {
        if (lastSyncDate == null || forceFullSync) {
          // Full sync: reconcile all active routines and remove obsolete ones
          await repository.reconcileWorkflows(pullResponse.updatedWorkflows);
        } else {
          // Delta sync: upsert new/updated and delete explicitly removed
          if (pullResponse.updatedWorkflows.isNotEmpty) {
            await repository.upsertWorkflows(pullResponse.updatedWorkflows);
          }
          if (pullResponse.deletedWorkflowIds.isNotEmpty) {
            await repository.deleteWorkflows(pullResponse.deletedWorkflowIds);
          }
        }

        // Upsert progression states for multi-session offline continuity
        if (pullResponse.progressionStates.isNotEmpty) {
          await repository.upsertProgressionStates(pullResponse.progressionStates);
        }

        // Save latest server timestamp for next delta sync
        await prefs?.setString(
          _lastSyncedKey,
          pullResponse.serverTimestamp.toUtc().toIso8601String(),
        );

        state = state.copyWith(
          status: SyncStatus.success,
          lastSyncedAt: pullResponse.serverTimestamp,
        );
        return true;
      } else {
        state = state.copyWith(
          status: SyncStatus.error,
          errorMessage: 'Failed to pull workflows from server',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  DateTime? _lastAutoSyncAttempt;

  /// Reacts to server health changes for zero-touch auto-sync when reconnecting.
  void handleHealthChange(ServerConnectionState health, bool simulateOffline) {
    if (simulateOffline || !health.isOnline) return;
    if (state.status == SyncStatus.syncing) return;

    final now = DateTime.now();
    // Debounce: don't auto-sync more often than once every 30 seconds
    if (_lastAutoSyncAttempt != null &&
        now.difference(_lastAutoSyncAttempt!) < const Duration(seconds: 30)) {
      return;
    }

    _lastAutoSyncAttempt = now;
    syncNow();
  }
}

/// Provider for SyncEngine state and operations.
final syncEngineProvider =
    StateNotifierProvider<SyncEngine, SyncState>((ref) {
  final httpClient = ref.watch(syncHttpClientProvider);
  final repository = ref.watch(workoutRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);

  final engine = SyncEngine(
    httpClient: httpClient,
    repository: repository,
    db: db,
  );

  // Automatically trigger sync when server transitions to online
  ref.listen<ServerConnectionState>(serverHealthProvider, (previous, next) {
    final simulateOffline = ref.read(serverHostProvider.notifier).simulateOffline;
    engine.handleHealthChange(next, simulateOffline);
  });

  return engine;
});
