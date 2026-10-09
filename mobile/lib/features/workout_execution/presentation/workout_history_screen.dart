import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../controller/workout_execution_controller.dart';
import '../data/workout_repository.dart';

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedSessionsAsync = ref.watch(completedSessionsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Workout History'),
        elevation: 0,
      ),
      body: completedSessionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error loading history: $err',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const _EmptyHistoryView();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: sessions.length + 1, // 1 for header summary
            separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 12 : 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _HistoryHeaderSummary(sessionCount: sessions.length);
              }
              final session = sessions[index - 1];
              return _HistorySessionCard(session: session);
            },
          );
        },
      ),
    );
  }
}

class _HistoryHeaderSummary extends StatelessWidget {
  final int sessionCount;

  const _HistoryHeaderSummary({required this.sessionCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sessionCount ${sessionCount == 1 ? 'Workout' : 'Workouts'} Completed',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap any session to inspect sets, loads, and volume.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 48,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Completed Workouts',
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'When you finish a workout, your duration, volume, and sets will be recorded here automatically.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySessionCard extends ConsumerStatefulWidget {
  final WorkoutSessionData session;

  const _HistorySessionCard({required this.session});

  @override
  ConsumerState<_HistorySessionCard> createState() => _HistorySessionCardState();
}

class _HistorySessionCardState extends ConsumerState<_HistorySessionCard> {
  bool _expanded = false;

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = dt.toLocal();
    final month = months[local.month - 1];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month ${local.day}, ${local.year} • $hour:$minute';
  }

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return '< 1m';
    final diff = end.difference(start);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return '${diff.inSeconds}s';
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Delete Workout?'),
        content: const Text(
          'Are you sure you want to remove this workout session from your local history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(workoutRepositoryProvider);
      await repo.deleteCompletedSession(widget.session.clientId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final logsAsync = ref.watch(sessionLogsFutureProvider(session.clientId));
    final durationStr = _formatDuration(session.startedAt, session.completedAt);
    final dateStr = _formatDate(session.startedAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded ? AppColors.primary.withValues(alpha: 0.5) : AppColors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Tappable Area
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Delete Action
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.sectionTitle,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: AppColors.onSurfaceVariant,
                        ),
                        tooltip: 'Delete Workout',
                        onPressed: () => _confirmDelete(context),
                      ),
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Metrics Badges
                  logsAsync.when(
                    loading: () => const SizedBox(
                      height: 24,
                      child: Text('Calculating metrics...', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    ),
                    error: (_, _) => const SizedBox(),
                    data: (logs) {
                      double totalVolume = 0;
                      int completedSets = 0;

                      for (final log in logs) {
                        if (log.completed) {
                          completedSets++;
                          final load = double.tryParse(log.actualLoad) ?? 0.0;
                          final reps = int.tryParse(log.actualReps) ?? 0;
                          totalVolume += load * reps;
                        }
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildBadge(
                            icon: Icons.timer_outlined,
                            label: durationStr,
                            color: AppColors.secondary,
                          ),
                          _buildBadge(
                            icon: Icons.fitness_center_rounded,
                            label: '${totalVolume.toStringAsFixed(totalVolume % 1 == 0 ? 0 : 1)} kg',
                            color: AppColors.primary,
                          ),
                          _buildBadge(
                            icon: Icons.check_circle_outline_rounded,
                            label: '$completedSets / ${logs.length} sets',
                            color: AppColors.success,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content: Exercises & Sets Details
          if (_expanded)
            logsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading sets: $err', style: const TextStyle(color: AppColors.error)),
              ),
              data: (logs) {
                if (logs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'No sets were logged for this session.',
                      style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                    ),
                  );
                }

                // Group logs by exercise name (nodeTypeSlug)
                final grouped = <String, List<WorkoutSetLogData>>{};
                for (final log in logs) {
                  final exName = log.nodeTypeSlug.isNotEmpty ? log.nodeTypeSlug : 'Exercise';
                  grouped.putIfAbsent(exName, () => []).add(log);
                }

                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    border: Border(
                      top: BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: grouped.entries.map((entry) {
                      final exerciseName = entry.key;
                      final exerciseSets = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Exercise name header
                            Row(
                              children: [
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  exerciseName,
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Sets list
                            ...exerciseSets.map((s) {
                              final isCompleted = s.completed;
                              final load = s.actualLoad.isNotEmpty ? s.actualLoad : s.prescribedLoad;
                              final reps = s.actualReps.isNotEmpty ? s.actualReps : s.prescribedReps;
                              final rpe = s.actualRpe;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Set ${s.setIndex}',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '$load kg × $reps',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isCompleted ? AppColors.onSurface : AppColors.onSurfaceVariant,
                                        decoration: isCompleted ? null : TextDecoration.lineThrough,
                                      ),
                                    ),
                                    if (rpe.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '@ RPE $rpe',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Icon(
                                      isCompleted
                                          ? Icons.check_circle_rounded
                                          : Icons.cancel_outlined,
                                      size: 16,
                                      color: isCompleted ? AppColors.success : AppColors.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
