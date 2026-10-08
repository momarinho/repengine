import 'package:meta/meta.dart';

@immutable
class WorkoutSetLog {
  final int? id;
  final int? sessionId;
  final String? sessionClientId;
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
    this.sessionClientId,
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
    if (sessionClientId != null) 'session_client_id': sessionClientId,
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
      sessionClientId: json['session_client_id'] as String?,
      workflowBlockId: json['workflow_block_id'] as int?,
      blockClientId: json['block_client_id']?.toString() ?? '',
      nodeTypeSlug: json['node_type_slug']?.toString() ?? '',
      setIndex: json['set_index'] is int
          ? json['set_index'] as int
          : int.tryParse(json['set_index']?.toString() ?? '0') ?? 0,
      prescribedReps: json['prescribed_reps']?.toString() ?? '',
      prescribedLoad: json['prescribed_load']?.toString() ?? '',
      prescribedIntensity: json['prescribed_intensity']?.toString() ?? '',
      prescribedRpe: json['prescribed_rpe']?.toString() ?? '',
      actualReps: json['actual_reps']?.toString() ?? '',
      actualLoad: json['actual_load']?.toString() ?? '',
      actualRpe: json['actual_rpe']?.toString() ?? '',
      actualRir: json['actual_rir']?.toString() ?? '',
      completed: json['completed'] as bool? ?? false,
      notes: json['notes']?.toString() ?? '',
      clientId: json['client_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now().toUtc(),
    );
  }
}
