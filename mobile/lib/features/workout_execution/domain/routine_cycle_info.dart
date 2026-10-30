import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';
import 'routine_model.dart';

@immutable
class RoutineCycleInfo {
  final RoutineSection? nextSection;
  final RoutineSection? lastCompletedSection;
  final WorkoutSessionData? lastCompletedSession;
  final int nextIndex;
  final int lastIndex;

  const RoutineCycleInfo({
    this.nextSection,
    this.lastCompletedSection,
    this.lastCompletedSession,
    this.nextIndex = 0,
    this.lastIndex = -1,
  });

  /// Computes the next section in the routine cycle based on previous completed sessions.
  /// Follows the same cycle detection logic as RepEngine Web Studio.
  static RoutineCycleInfo calculate({
    required List<RoutineSection> sections,
    required List<WorkoutSessionData> completedSessions,
    int? workflowId,
  }) {
    if (sections.isEmpty) {
      return const RoutineCycleInfo();
    }

    final relevantSessions = completedSessions.where((s) {
      if (s.status == 'active') return false;
      if (workflowId != null && s.workflowId != workflowId) return false;
      return s.sectionId.isNotEmpty || s.sectionTitle.isNotEmpty;
    }).toList();

    // Sort descending by completion time (or start time if completedAt is null)
    relevantSessions.sort((a, b) {
      final dateA = a.completedAt ?? a.startedAt;
      final dateB = b.completedAt ?? b.startedAt;
      final cmp = dateB.compareTo(dateA);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });

    final lastCompleted = relevantSessions.isNotEmpty ? relevantSessions.first : null;
    if (lastCompleted == null) {
      return RoutineCycleInfo(
        nextSection: sections.first,
        nextIndex: 0,
        lastIndex: -1,
      );
    }

    int lastIdx = -1;
    // 1. Match by section ID
    if (lastCompleted.sectionId.isNotEmpty) {
      lastIdx = sections.indexWhere((s) => s.id == lastCompleted.sectionId);
    }

    // 2. Fallback: match by title
    if (lastIdx == -1 && lastCompleted.sectionTitle.isNotEmpty) {
      final targetTitle = lastCompleted.sectionTitle.trim().toLowerCase();
      lastIdx = sections.indexWhere((s) => s.title.trim().toLowerCase() == targetTitle);

      // Substring match
      if (lastIdx == -1) {
        lastIdx = sections.indexWhere((s) {
          final sTitle = s.title.trim().toLowerCase();
          return targetTitle.contains(sTitle) || sTitle.contains(targetTitle);
        });
      }

      // Day / Dia number match
      if (lastIdx == -1) {
        final dayMatch =
            RegExp(r'(?:day|dia)\s*(\d+)', caseSensitive: false).firstMatch(targetTitle);
        if (dayMatch != null) {
          final dayNum = dayMatch.group(1);
          lastIdx = sections.indexWhere((s) {
            final sMatch =
                RegExp(r'(?:day|dia)\s*(\d+)', caseSensitive: false).firstMatch(s.title);
            return sMatch != null && sMatch.group(1) == dayNum;
          });
        }
      }
    }

    if (lastIdx == -1) {
      return RoutineCycleInfo(
        nextSection: sections.first,
        lastCompletedSession: lastCompleted,
        nextIndex: 0,
        lastIndex: -1,
      );
    }

    final nextIdx = (lastIdx + 1) % sections.length;
    return RoutineCycleInfo(
      nextSection: sections[nextIdx],
      lastCompletedSection: sections[lastIdx],
      lastCompletedSession: lastCompleted,
      nextIndex: nextIdx,
      lastIndex: lastIdx,
    );
  }
}
