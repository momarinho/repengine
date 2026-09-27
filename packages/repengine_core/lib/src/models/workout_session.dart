import 'package:meta/meta.dart';

import 'workout_set_log.dart';

@immutable
class WorkoutSession {
  final int? id;
  final int workflowId;
  final int userId;
  final String sectionId;
  final String sectionTitle;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String notes;
  final int logCount;
  final String? clientId;
  final List<WorkoutSetLog> logs;

  const WorkoutSession({
    this.id,
    required this.workflowId,
    required this.userId,
    required this.sectionId,
    required this.sectionTitle,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.notes = '',
    this.logCount = 0,
    this.clientId,
    this.logs = const [],
  });

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'workflow_id': workflowId,
    'user_id': userId,
    'section_id': sectionId,
    'section_title': sectionTitle,
    'status': status,
    'started_at': startedAt.toIso8601String(),
    if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    'notes': notes,
    'log_count': logCount,
    if (clientId != null) 'client_id': clientId,
    if (logs.isNotEmpty) 'logs': logs.map((l) => l.toJson()).toList(),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as int?,
      workflowId: json['workflow_id'] as int,
      userId: json['user_id'] as int,
      sectionId: json['section_id'] as String? ?? '',
      sectionTitle: json['section_title'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      notes: json['notes'] as String? ?? '',
      logCount: json['log_count'] as int? ?? 0,
      clientId: json['client_id'] as String?,
      logs:
          (json['logs'] as List<dynamic>?)
              ?.map((e) => WorkoutSetLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
