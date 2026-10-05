import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../data/workout_repository.dart';

/// Stream da sessão ativa no momento
final activeSessionStreamProvider = StreamProvider<WorkoutSessionData?>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.watchActiveSession();
});

/// Stream das séries da sessão ativa
final activeSessionLogsStreamProvider =
    StreamProvider.family<List<WorkoutSetLogData>, String>((ref, sessionId) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.watchSessionLogs(sessionId);
});

/// Stream da quantidade de itens pendentes na outbox
final pendingSyncCountStreamProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.watchPendingSyncCount();
});

/// Stream de todos os itens da fila de sincronização (para o Debug Drawer)
final syncQueueStreamProvider = StreamProvider<List<SyncQueueData>>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.watchSyncQueue();
});

/// Estado do cronômetro de descanso
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
