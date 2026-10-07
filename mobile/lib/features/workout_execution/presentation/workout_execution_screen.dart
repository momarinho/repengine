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
              tooltip: 'Diagnóstico & Rede',
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
                  sectionTitle: 'Treino A - Agachamento & Supino',
                  startedAt: DateTime.now().toUtc(),
                );
              },
            );
          }

          return Stack(
            children: [
              // Visualizador de séries da sessão ativa
              _ActiveSessionContent(sessionClientId: session.clientId),

              // Overlay de cronômetro circular se ativo
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
        error: (err, _) => Center(child: Text('Erro: $err')),
      ),
      bottomNavigationBar: activeSessionAsync.maybeWhen(
        data: (session) {
          if (session == null) return null;
          return ThumbZonePad(
            initialLoad: 100.0,
            initialReps: 5,
            exerciseName: 'Agachamento Livre',
            onLogSet: (load, reps, rpe) async {
              final repo = ref.read(workoutRepositoryProvider);
              final logs = ref.read(activeSessionLogsStreamProvider(session.clientId)).value ?? [];
              final nextIndex = logs.length + 1;
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

              // Inicia cronômetro de descanso de 90 segundos automaticamente
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
                  const Text('SESSÃO ATIVA', style: AppTypography.labelLarge),
                  Text(
                    'Treino A (GZCLP Hybrid)',
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
                label: const Text('Finalizar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onBackground,
                  side: const BorderSide(color: AppColors.outlineVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('SÉRIES CONCLUÍDAS', style: AppTypography.labelSmall),
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
                          'Nenhuma série concluída ainda.',
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ajuste o peso no painel abaixo e toque em Concluir Série!',
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
              error: (err, _) => Center(child: Text('Erro: $err')),
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
              'Pronto para Treinar?',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'O RepEngine HUD grava cada repetição 100% offline no celular, garantindo latência zero na academia.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('INICIAR TREINO A (GZCLP HYBRID)'),
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
          'Testando...',
        );
      }
      if (health.state == ConnectionStateEnum.offline) {
        if (pendingCount > 0) {
          return (
            const Color(0x22E6C384),
            const Color(0xFFE6C384),
            const Color(0xFFE6C384),
            Icons.offline_bolt_rounded,
            'Modo Academia ($pendingCount)',
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
          'Sincronizado',
        );
      }
      return (
        const Color(0x22E6C384),
        const Color(0xFFE6C384),
        const Color(0xFFE6C384),
        Icons.cloud_upload_rounded,
        'Pendente ($pendingCount)',
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
