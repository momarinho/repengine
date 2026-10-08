import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/server_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../sync/application/sync_engine.dart';
import '../controller/workout_execution_controller.dart';
import '../data/workout_repository.dart';
import '../domain/routine_model.dart';
import 'widgets/circular_rest_timer.dart';
import 'widgets/debug_settings_drawer.dart';
import 'widgets/routine_selector_view.dart';
import 'widgets/set_log_card.dart';
import 'widgets/thumb_zone_pad.dart';
import 'widgets/workout_summary_dialog.dart';

class WorkoutExecutionScreen extends ConsumerWidget {
  const WorkoutExecutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSessionAsync = ref.watch(activeSessionStreamProvider);
    final pendingSyncCount = ref.watch(pendingSyncCountStreamProvider).value ?? 0;
    final restTimer = ref.watch(restTimerProvider);
    final health = ref.watch(serverHealthProvider);
    final syncState = ref.watch(syncEngineProvider);

    return Scaffold(
      endDrawer: const DebugSettingsDrawer(),
      appBar: AppBar(
        title: Builder(
          builder: (context) => GestureDetector(
            onDoubleTap: () => Scaffold.of(context).openEndDrawer(),
            child: const Text('RepEngine HUD'),
          ),
        ),
        actions: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => Scaffold.of(context).openEndDrawer(),
              child: _CloudSyncBadge(
                health: health,
                pendingCount: pendingSyncCount,
                isSyncing: syncState.status == SyncStatus.syncing,
              ),
            ),
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.tune_rounded, size: 20),
              tooltip: 'Diagnostics & Network',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: activeSessionAsync.when(
        data: (session) {
          if (session == null) {
            return RoutineSelectorView(
              onStartWorkout: ({
                required workflowId,
                required sectionId,
                required sectionTitle,
              }) async {
                final repo = ref.read(workoutRepositoryProvider);
                final uniqueId = 'sess-${DateTime.now().millisecondsSinceEpoch}';
                ref.read(activeExerciseIndexProvider.notifier).state = 0;
                await repo.startSession(
                  clientId: uniqueId,
                  workflowId: workflowId,
                  sectionId: sectionId,
                  sectionTitle: sectionTitle,
                  startedAt: DateTime.now().toUtc(),
                );
              },
            );
          }

          final routines = ref.watch(parsedRoutinesStreamProvider).value ?? [ParsedRoutine.defaultGzclp()];
          final routine = routines.firstWhere(
            (r) => r.id == session.workflowId,
            orElse: () => routines.first,
          );
          final section = routine.sections.firstWhere(
            (s) => s.id == session.sectionId,
            orElse: () => routine.sections.isNotEmpty ? routine.sections.first : ParsedRoutine.defaultGzclp().sections.first,
          );
          final exercises = section.exercises.isNotEmpty
              ? section.exercises
              : ParsedRoutine.defaultGzclp().sections.first.exercises;
          final activeExIndex = ref.watch(activeExerciseIndexProvider).clamp(0, exercises.length - 1);

          return Stack(
            children: [
              // Active session sets viewer
              _ActiveSessionContent(
                session: session,
                exercises: exercises,
                activeExerciseIndex: activeExIndex,
              ),

              // Circular rest timer overlay if active
              if (restTimer.isActive)
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: CircularRestTimerWidget(
                    totalSeconds: restTimer.durationSeconds,
                    onFinished: () {
                      ref.read(restTimerProvider.notifier).stop();
                    },
                    onDismissed: () {
                      ref.read(restTimerProvider.notifier).stop();
                    },
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      bottomNavigationBar: activeSessionAsync.maybeWhen(
        data: (session) {
          if (session == null) return null;
          final routines = ref.watch(parsedRoutinesStreamProvider).value ?? [ParsedRoutine.defaultGzclp()];
          final routine = routines.firstWhere(
            (r) => r.id == session.workflowId,
            orElse: () => routines.first,
          );
          final section = routine.sections.firstWhere(
            (s) => s.id == session.sectionId,
            orElse: () => routine.sections.isNotEmpty ? routine.sections.first : ParsedRoutine.defaultGzclp().sections.first,
          );
          final exercises = section.exercises.isNotEmpty
              ? section.exercises
              : ParsedRoutine.defaultGzclp().sections.first.exercises;
          final activeExIndex = ref.watch(activeExerciseIndexProvider).clamp(0, exercises.length - 1);
          final currentExercise = exercises[activeExIndex];

          final logs = ref.watch(activeSessionLogsStreamProvider(session.clientId)).value ?? [];
          final suggestion = ref.watch(
            progressionSuggestionProvider((
              blockClientId: currentExercise.blockClientId,
              logCount: logs.length,
              fallbackLoad: currentExercise.targetLoad,
              fallbackReps: int.tryParse(currentExercise.reps) ?? 5,
            )),
          ).value ?? ProgressionSuggestion(load: currentExercise.targetLoad, reps: int.tryParse(currentExercise.reps) ?? 5);

          return ThumbZonePad(
            key: ValueKey('pad_${session.clientId}_${currentExercise.blockClientId}_${logs.length}_${suggestion.load}'),
            initialLoad: suggestion.load,
            initialReps: suggestion.reps,
            progressionNote: suggestion.reasoning,
            exerciseName: currentExercise.name,
            onLogSet: (load, reps, rpe) async {
              final repo = ref.read(workoutRepositoryProvider);
              final currentLogs = ref.read(activeSessionLogsStreamProvider(session.clientId)).value ?? [];
              final nextIndex = currentLogs.length + 1;
              final logUniqueId = 'log-${DateTime.now().millisecondsSinceEpoch}';

              await repo.logSet(
                clientId: logUniqueId,
                sessionClientId: session.clientId,
                blockClientId: currentExercise.blockClientId,
                nodeTypeSlug: currentExercise.nodeTypeSlug,
                setIndex: nextIndex,
                prescribedReps: reps.toString(),
                prescribedLoad: load.toString(),
                actualReps: reps.toString(),
                actualLoad: load.toString(),
                actualRpe: rpe?.toString() ?? '',
                completed: true,
                createdAt: DateTime.now().toUtc(),
              );

              // Automatically start rest timer for this exercise
              ref.read(restTimerProvider.notifier).start(seconds: currentExercise.restSeconds);
            },
          );
        },
        orElse: () => null,
      ),
    );
  }
}

class _ActiveSessionContent extends ConsumerWidget {
  final WorkoutSessionData session;
  final List<RoutineExercise> exercises;
  final int activeExerciseIndex;

  const _ActiveSessionContent({
    required this.session,
    required this.exercises,
    required this.activeExerciseIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(activeSessionLogsStreamProvider(session.clientId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ACTIVE SESSION', style: AppTypography.labelLarge),
                    Text(
                      session.sectionTitle,
                      style: AppTypography.titleLarge.copyWith(fontSize: 20),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final logs = logsAsync.value ?? [];
                  showDialog(
                    context: context,
                    builder: (ctx) => WorkoutSummaryDialog(
                      session: session,
                      logs: logs,
                      onConfirm: () async {
                        await ref
                            .read(workoutRepositoryProvider)
                            .completeSession(session.clientId);
                        ref.read(restTimerProvider.notifier).stop();
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Finish'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onBackground,
                  side: const BorderSide(color: AppColors.outlineVariant),
                ),
              ),
            ],
          ),

          if (exercises.length > 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: exercises.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final ex = exercises[index];
                  final isSelected = index == activeExerciseIndex;
                  return ChoiceChip(
                    label: Text(ex.name),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(activeExerciseIndexProvider.notifier).state = index;
                    },
                    selectedColor: AppColors.primaryContainer,
                    backgroundColor: AppColors.surfaceContainer,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.onBackground : AppColors.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Text('COMPLETED SETS', style: AppTypography.labelSmall),
          const SizedBox(height: 8),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 48,
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No completed sets yet.',
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Adjust weight below and tap Log Set!',
                          style: AppTypography.labelSmall,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return SetLogCard(log: log);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudSyncBadge extends StatelessWidget {
  final ServerConnectionState health;
  final int pendingCount;
  final bool isSyncing;

  const _CloudSyncBadge({
    required this.health,
    required this.pendingCount,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color text, IconData icon, String label) = () {
      if (isSyncing) {
        return (
          const Color(0x227AA89F),
          AppColors.secondary,
          AppColors.secondary,
          Icons.sync_rounded,
          'Syncing with PC...',
        );
      }
      if (health.state == ConnectionStateEnum.checking) {
        return (
          const Color(0x227AA89F),
          AppColors.secondary,
          AppColors.secondary,
          Icons.sync_rounded,
          'Connecting...',
        );
      }
      if (health.state == ConnectionStateEnum.offline) {
        if (pendingCount > 0) {
          return (
            const Color(0x22E6C384),
            const Color(0xFFE6C384),
            const Color(0xFFE6C384),
            Icons.offline_bolt_rounded,
            'Gym Mode ($pendingCount)',
          );
        }
        return (
          const Color(0x22727169),
          AppColors.outline,
          AppColors.onSurfaceVariant,
          Icons.cloud_off_rounded,
          'PC Offline',
        );
      }
      // Online
      if (pendingCount == 0) {
        return (
          const Color(0x2298BB6C),
          AppColors.success,
          AppColors.success,
          Icons.cloud_done_rounded,
          'Synced',
        );
      }
      return (
        const Color(0x22E6C384),
        const Color(0xFFE6C384),
        const Color(0xFFE6C384),
        Icons.cloud_upload_rounded,
        'Pending ($pendingCount)',
      );
    }();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
