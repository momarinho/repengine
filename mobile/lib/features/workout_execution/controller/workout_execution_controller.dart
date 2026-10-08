import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../data/workout_repository.dart';
import '../domain/routine_model.dart';

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
final progressionSuggestionProvider = FutureProvider.family<
    ProgressionSuggestion,
    ({String blockClientId, int logCount, double? fallbackLoad, int? fallbackReps})>(
  (ref, params) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getSuggestedProgressionForBlock(
      params.blockClientId,
      fallbackLoad: params.fallbackLoad ?? 100.0,
      fallbackReps: params.fallbackReps ?? 5,
    );
  },
);

/// Stream of all synced routines parsed with their sections and exercises
final parsedRoutinesStreamProvider = StreamProvider<List<ParsedRoutine>>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.watchRoutines().map((routines) {
    if (routines.isEmpty) {
      return [ParsedRoutine.defaultGzclp()];
    }
    return routines.map(ParsedRoutine.fromRoutine).toList();
  });
});

/// Currently selected routine ID on the dashboard (defaults to first available)
final selectedRoutineIdProvider = StateProvider<int?>((ref) => null);

/// Currently selected section/day ID on the dashboard
final selectedSectionIdProvider = StateProvider<String?>((ref) => null);

/// Currently selected exercise index in active workout session
final activeExerciseIndexProvider = StateProvider<int>((ref) => 0);


