import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../data/workout_repository.dart';

/// Stream of currently active workout session
final activeSessionStreamProvider = StreamProvider<WorkoutSessionData?>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.watchActiveSession();
});

/// Stream of logged sets for active session
final activeSessionLogsStreamProvider =
    StreamProvider.family<List<WorkoutSetLogData>, String>((ref, sessionId) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.watchSessionLogs(sessionId);
});

/// Stream of pending item count in sync outbox
final pendingSyncCountStreamProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.watchPendingSyncCount();
});

/// Stream of all sync queue items (for Debug Drawer)
final syncQueueStreamProvider = StreamProvider<List<SyncQueueData>>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.watchSyncQueue();
});

/// Rest timer state
class RestTimerState {
  final bool isActive;
  final int durationSeconds;

  const RestTimerState({
    this.isActive = false,
    this.durationSeconds = 90,
  });

  RestTimerState copyWith({bool? isActive, int? durationSeconds}) {
    return RestTimerState(
      isActive: isActive ?? this.isActive,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}

class RestTimerNotifier extends StateNotifier<RestTimerState> {
  RestTimerNotifier() : super(const RestTimerState());

  void start({int seconds = 90}) {
    state = RestTimerState(isActive: true, durationSeconds: seconds);
  }

  void stop() {
    state = state.copyWith(isActive: false);
  }
}

final restTimerProvider =
    StateNotifierProvider<RestTimerNotifier, RestTimerState>((ref) {
  return RestTimerNotifier();
});

/// Reactive provider calculating progression suggestion for an exercise block
final progressionSuggestionProvider =
    FutureProvider.family<ProgressionSuggestion, ({String blockClientId, int logCount})>(
  (ref, params) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getSuggestedProgressionForBlock(params.blockClientId);
  },
);

