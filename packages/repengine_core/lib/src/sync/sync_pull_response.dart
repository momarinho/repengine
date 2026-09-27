import 'package:meta/meta.dart';

import '../models/workflow.dart';

@immutable
class SyncPullResponse {
  final List<Workflow> updatedWorkflows;
  final List<int> deletedWorkflowIds;
  final DateTime serverTimestamp;

  const SyncPullResponse({
    this.updatedWorkflows = const [],
    this.deletedWorkflowIds = const [],
    required this.serverTimestamp,
  });

  Map<String, dynamic> toJson() => {
    'updated_workflows': updatedWorkflows.map((w) => w.toJson()).toList(),
    'deleted_workflow_ids': deletedWorkflowIds,
    'server_timestamp': serverTimestamp.toIso8601String(),
  };

  factory SyncPullResponse.fromJson(Map<String, dynamic> json) {
    return SyncPullResponse(
      updatedWorkflows:
          (json['updated_workflows'] as List<dynamic>?)
              ?.map((e) => Workflow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      deletedWorkflowIds:
          (json['deleted_workflow_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      serverTimestamp: DateTime.parse(json['server_timestamp'] as String),
    );
  }
}
