import 'package:meta/meta.dart';

@immutable
class WorkoutSetLog {
  final int? id;
  final int? sessionId;
  final int? workflowBlockId;
  final String blockClientId;
  final String nodeTypeSlug;
  final int setIndex;
  final String prescribedReps;
  final String prescribedLoad;
  final String prescribedIntensity;
  final String prescribedRpe;
  final String actualReps;
  final String actualLoad;
  final String actualRpe;
  final String actualRir;
  final bool completed;
  final String notes;
  final String? clientId;
  final DateTime createdAt;

  const WorkoutSetLog({
    this.id,
    this.sessionId,
    this.workflowBlockId,
    required this.blockClientId,
    required this.nodeTypeSlug,
    required this.setIndex,
    this.prescribedReps = '',
    this.prescribedLoad = '',
    this.prescribedIntensity = '',
    this.prescribedRpe = '',
    this.actualReps = '',
    this.actualLoad = '',
    this.actualRpe = '',
    this.actualRir = '',
    this.completed = false,
    this.notes = '',
    this.clientId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (sessionId != null) 'session_id': sessionId,
    if (workflowBlockId != null) 'workflow_block_id': workflowBlockId,
    'block_client_id': blockClientId,
    'node_type_slug': nodeTypeSlug,
    'set_index': setIndex,
    'prescribed_reps': prescribedReps,
    'prescribed_load': prescribedLoad,
    'prescribed_intensity': prescribedIntensity,
    'prescribed_rpe': prescribedRpe,
    'actual_reps': actualReps,
    'actual_load': actualLoad,
    'actual_rpe': actualRpe,
    'actual_rir': actualRir,
    'completed': completed,
    'notes': notes,
    if (clientId != null) 'client_id': clientId,
    'created_at': createdAt.toIso8601String(),
  };

  factory WorkoutSetLog.fromJson(Map<String, dynamic> json) {
    return WorkoutSetLog(
      id: json['id'] as int?,
      sessionId: json['session_id'] as int?,
      workflowBlockId: json['workflow_block_id'] as int?,
      blockClientId: json['block_client_id'] as String? ?? '',
      nodeTypeSlug: json['node_type_slug'] as String? ?? '',
      setIndex: json['set_index'] as int? ?? 0,
      prescribedReps: json['prescribed_reps'] as String? ?? '',
      prescribedLoad: json['prescribed_load'] as String? ?? '',
      prescribedIntensity: json['prescribed_intensity'] as String? ?? '',
      prescribedRpe: json['prescribed_rpe'] as String? ?? '',
      actualReps: json['actual_reps'] as String? ?? '',
      actualLoad: json['actual_load'] as String? ?? '',
      actualRpe: json['actual_rpe'] as String? ?? '',
      actualRir: json['actual_rir'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      clientId: json['client_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now().toUtc(),
    );
  }
}
