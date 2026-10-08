import 'package:meta/meta.dart';

@immutable
class ProgressionState {
  final int id;
  final int userId;
  final int workflowId;
  final int? workflowBlockId;
  final String blockKey;
  final String nodeTypeSlug;
  final String stateType;
  final String? exerciseName;
  final String outcome;
  final String? currentLoad;
  final String? suggestedLoad;
  final int? currentWeek;
  final int? suggestedWeek;
  final String? summary;
  final DateTime updatedAt;

  const ProgressionState({
    required this.id,
    required this.userId,
    required this.workflowId,
    this.workflowBlockId,
    required this.blockKey,
    required this.nodeTypeSlug,
    required this.stateType,
    this.exerciseName,
    required this.outcome,
    this.currentLoad,
    this.suggestedLoad,
    this.currentWeek,
    this.suggestedWeek,
    this.summary,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'workflow_id': workflowId,
    if (workflowBlockId != null) 'workflow_block_id': workflowBlockId,
    'block_key': blockKey,
    'node_type_slug': nodeTypeSlug,
    'state_type': stateType,
    if (exerciseName != null) 'exercise_name': exerciseName,
    'outcome': outcome,
    if (currentLoad != null) 'current_load': currentLoad,
    if (suggestedLoad != null) 'suggested_load': suggestedLoad,
    if (currentWeek != null) 'current_week': currentWeek,
    if (suggestedWeek != null) 'suggested_week': suggestedWeek,
    if (summary != null) 'summary': summary,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory ProgressionState.fromJson(Map<String, dynamic> json) =>
      ProgressionState(
        id: json['id'] as int? ?? 0,
        userId: (json['user_id'] as num?)?.toInt() ?? 1,
        workflowId: (json['workflow_id'] as num?)?.toInt() ?? 0,
        workflowBlockId: json['workflow_block_id'] as int?,
        blockKey: json['block_key']?.toString() ?? '',
        nodeTypeSlug: json['node_type_slug']?.toString() ?? '',
        stateType: json['state_type']?.toString() ?? '',
        exerciseName: json['exercise_name'] as String?,
        outcome: json['outcome']?.toString() ?? 'pending',
        currentLoad: json['current_load'] as String?,
        suggestedLoad: json['suggested_load'] as String?,
        currentWeek: json['current_week'] as int?,
        suggestedWeek: json['suggested_week'] as int?,
        summary: json['summary'] as String?,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'].toString())
            : DateTime.now().toUtc(),
      );
}
