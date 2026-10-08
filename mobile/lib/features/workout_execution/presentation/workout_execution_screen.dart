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
    final logs = logsAsync.value ?? [];
    final currentExercise = exercises[activeExerciseIndex];

    // Filter sets logged specifically for the active exercise block
    final exerciseLogs = logs
        .where((l) => l.blockClientId == currentExercise.blockClientId)
        .toList();
    final completedSetsCount = exerciseLogs.length;
    final totalSets = currentExercise.sets > 0 ? currentExercise.sets : 3;
    final currentSetNumber = (completedSetsCount + 1).clamp(1, totalSets);

    final suggestion = ref.watch(
      progressionSuggestionProvider((
        blockClientId: currentExercise.blockClientId,
        logCount: completedSetsCount,
        fallbackLoad: currentExercise.targetLoad,
        fallbackReps: int.tryParse(currentExercise.reps) ?? 5,
      )),
    ).value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          // 1. ACTIVE SESSION TOP BAR
          Row(
            children: [
              Text(
                'ACTIVE SESSION',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0x2298BB6C),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'LIVE',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.success,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  session.sectionTitle,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () {
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
                icon: const Icon(Icons.done_all, size: 14),
                label: const Text('Finish'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onBackground,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          // 2. EXERCISE SWITCHER CHIPS (if multiple exercises exist)
          if (exercises.length > 1) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: exercises.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final ex = exercises[index];
                  final isSelected = index == activeExerciseIndex;
                  final exSetsDone = logs.where((l) => l.blockClientId == ex.blockClientId).length;
                  final isAllDone = exSetsDone >= ex.sets && ex.sets > 0;

                  return ChoiceChip(
                    avatar: isAllDone
                        ? const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success)
                        : null,
                    label: Text(ex.name),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(activeExerciseIndexProvider.notifier).state = index;
                    },
                    selectedColor: AppColors.primaryContainer,
                    backgroundColor: AppColors.surfaceContainer,
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.onBackground : AppColors.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 4),

          // 3. MODERN HERO ACTIVE EXERCISE HUD CARD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Exercise Name & Rest Timer Pill
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentExercise.name,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onBackground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${currentExercise.restSeconds}s rest',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.tertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Compact 3-Column Display Metrics
                Row(
                  children: [
                    Text(
                      'SET ',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$currentSetNumber',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '/$totalSets',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'TARGET ',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${currentExercise.reps} reps',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 13,
                        color: AppColors.onBackground,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'LOAD ',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${currentExercise.targetLoad.toStringAsFixed(currentExercise.targetLoad % 1 == 0 ? 0 : 1)} kg',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 13,
                        color: AppColors.onBackground,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Set Completion Progress Pills
                Row(
                  children: List.generate(totalSets, (index) {
                    final isDone = index < completedSetsCount;
                    final isCurrent = index == completedSetsCount;
                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: EdgeInsets.only(right: index < totalSets - 1 ? 3 : 0),
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.primary
                              : (isCurrent
                                  ? AppColors.primary.withValues(alpha: 0.45)
                                  : AppColors.surfaceContainerHighest),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),

                // Autoregulation / Progression tracker note (if present)
                if (suggestion != null && suggestion.reasoning != null && suggestion.reasoning!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.trending_up, size: 11, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          suggestion.reasoning!,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 4. COMPLETED SETS SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'COMPLETED SETS',
                style: AppTypography.labelSmall.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (logs.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${logs.length}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          Expanded(
            child: logsAsync.when(
              data: (logsList) {
                if (logsList.isEmpty) {
                  return const SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center_rounded,
                              size: 28,
                              color: Color(0x66DBC0C4),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'No completed sets yet.',
                              style: AppTypography.bodyMedium,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Adjust weight below and tap Log Set!',
                              style: AppTypography.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: logsList.length,
                  itemBuilder: (context, index) {
                    final log = logsList[index];
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
