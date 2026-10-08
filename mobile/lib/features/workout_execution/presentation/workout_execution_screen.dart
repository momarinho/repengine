import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/server_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../controller/workout_execution_controller.dart';
import '../data/workout_repository.dart';
import 'widgets/circular_rest_timer.dart';
import 'widgets/debug_settings_drawer.dart';
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
            return _EmptyWorkoutView(
              onStart: () async {
                final repo = ref.read(workoutRepositoryProvider);
                final uniqueId = 'sess-${DateTime.now().millisecondsSinceEpoch}';
                await repo.startSession(
                  clientId: uniqueId,
                  workflowId: 2,
                  sectionId: 'sec_day1',
                  sectionTitle: 'Workout A - Squat & Bench',
                  startedAt: DateTime.now().toUtc(),
                );
              },
            );
          }

          return Stack(
            children: [
              // Active session sets viewer
              _ActiveSessionContent(sessionClientId: session.clientId),

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
          final logs = ref.watch(activeSessionLogsStreamProvider(session.clientId)).value ?? [];
          final suggestion = ref.watch(
            progressionSuggestionProvider((
              blockClientId: 'blk_squat',
              logCount: logs.length,
            )),
          ).value ?? const ProgressionSuggestion(load: 100.0, reps: 5);

          return ThumbZonePad(
            key: ValueKey('pad_${session.clientId}_${logs.length}_${suggestion.load}'),
            initialLoad: suggestion.load,
            initialReps: suggestion.reps,
            progressionNote: suggestion.reasoning,
            exerciseName: 'Barbell Back Squat',
            onLogSet: (load, reps, rpe) async {
              final repo = ref.read(workoutRepositoryProvider);
              final currentLogs = ref.read(activeSessionLogsStreamProvider(session.clientId)).value ?? [];
              final nextIndex = currentLogs.length + 1;
              final logUniqueId = 'log-${DateTime.now().millisecondsSinceEpoch}';

              await repo.logSet(
                clientId: logUniqueId,
                sessionClientId: session.clientId,
                blockClientId: 'blk_squat',
                nodeTypeSlug: 'exercise_squat',
                setIndex: nextIndex,
                prescribedReps: reps.toString(),
                prescribedLoad: load.toString(),
                actualReps: reps.toString(),
                actualLoad: load.toString(),
                actualRpe: rpe?.toString() ?? '',
                completed: true,
                createdAt: DateTime.now().toUtc(),
              );

              // Automatically start 90s rest timer
              ref.read(restTimerProvider.notifier).start(seconds: 90);
            },
          );
        },
        orElse: () => null,
      ),
    );
  }
}

class _ActiveSessionContent extends ConsumerWidget {
  final String sessionClientId;

  const _ActiveSessionContent({required this.sessionClientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(activeSessionLogsStreamProvider(sessionClientId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ACTIVE SESSION', style: AppTypography.labelLarge),
                  Text(
                    'Workout A (GZCLP Hybrid)',
                    style: AppTypography.titleLarge.copyWith(fontSize: 20),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final logs = logsAsync.value ?? [];
                  final session = ref.read(activeSessionStreamProvider).value;
                  if (session == null) return;

                  showDialog(
                    context: context,
                    builder: (ctx) => WorkoutSummaryDialog(
                      session: session,
                      logs: logs,
                      onConfirm: () async {
                        await ref
                            .read(workoutRepositoryProvider)
                            .completeSession(sessionClientId);
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
          const SizedBox(height: 16),
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

class _EmptyWorkoutView extends StatelessWidget {
  final VoidCallback onStart;

  const _EmptyWorkoutView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Icon(
                Icons.bolt,
                size: 54,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ready to Train?',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'RepEngine HUD logs every set 100% offline on your device, ensuring zero latency at the gym.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('START WORKOUT A (GZCLP HYBRID)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onBackground,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudSyncBadge extends StatelessWidget {
  final ServerConnectionState health;
  final int pendingCount;

  const _CloudSyncBadge({
    required this.health,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color text, IconData icon, String label) = () {
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
