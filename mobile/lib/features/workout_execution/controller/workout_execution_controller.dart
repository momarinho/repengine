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

/// Stream of all completed workout sessions (for History View)
final completedSessionsStreamProvider = StreamProvider<List<WorkoutSessionData>>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.watchCompletedSessions();
});

/// Future provider fetching all set logs recorded in a session
final sessionLogsFutureProvider = FutureProvider.family<List<WorkoutSetLogData>, String>((ref, sessionClientId) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.getSessionLogs(sessionClientId);
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
    ({
      String blockClientId,
      String? sectionId,
      String? sectionTitle,
      int logCount,
      double? fallbackLoad,
      int? fallbackReps,
    })>(
  (ref, params) async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.getSuggestedProgressionForBlock(
      params.blockClientId,
      sectionId: params.sectionId,
      sectionTitle: params.sectionTitle,
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

/// State of customized exercises for the active workout session.
/// Supports swapping, adding, and removing exercises on the fly.
class ActiveSessionExercisesNotifier extends StateNotifier<List<RoutineExercise>?> {
  String? _currentSessionId;
  String? get currentSessionId => _currentSessionId;

  ActiveSessionExercisesNotifier() : super(null);

  void initialize(String sessionId, List<RoutineExercise> initial) {
    _currentSessionId = sessionId;
    state = List.of(initial);
  }

  void reset() {
    _currentSessionId = null;
    state = null;
  }

  void swapExercise(int index, RoutineExercise updated) {
    if (state == null || index < 0 || index >= state!.length) return;
    final list = List<RoutineExercise>.of(state!);
    list[index] = updated;
    state = list;
  }

  void addExercise(RoutineExercise exercise) {
    final list = state != null ? List<RoutineExercise>.of(state!) : <RoutineExercise>[];
    list.add(exercise);
    state = list;
  }

  void removeExercise(int index) {
    if (state == null || index < 0 || index >= state!.length || state!.length <= 1) return;
    final list = List<RoutineExercise>.of(state!);
    list.removeAt(index);
    state = list;
  }
}

final activeSessionExercisesProvider =
    StateNotifierProvider<ActiveSessionExercisesNotifier, List<RoutineExercise>?>((ref) {
  return ActiveSessionExercisesNotifier();
});



