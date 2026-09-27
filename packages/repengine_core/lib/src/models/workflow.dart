import 'package:meta/meta.dart';

@immutable
class WorkflowBlock {
  final int? id;
  final int? workflowId;
  final String nodeTypeSlug;
  final int position;
  final Map<String, dynamic> data;

  const WorkflowBlock({
    this.id,
    this.workflowId,
    required this.nodeTypeSlug,
    required this.position,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (workflowId != null) 'workflow_id': workflowId,
    'node_type_slug': nodeTypeSlug,
    'position': position,
    'data': data,
  };

  factory WorkflowBlock.fromJson(Map<String, dynamic> json) => WorkflowBlock(
    id: json['id'] as int?,
    workflowId: json['workflow_id'] as int?,
    nodeTypeSlug: json['node_type_slug'] as String,
    position: json['position'] as int? ?? 0,
    data: (json['data'] as Map<String, dynamic>?) ?? const {},
  );
}

@immutable
class Workflow {
  final int id;
  final int userId;
  final String name;
  final String description;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int blockCount;
  final List<WorkflowBlock> blocks;

  const Workflow({
    required this.id,
    required this.userId,
    required this.name,
    this.description = '',
    this.isPublic = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.blockCount = 0,
    this.blocks = const [],
  });

  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'description': description,
    'is_public': isPublic,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
    'block_count': blockCount,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  factory Workflow.fromJson(Map<String, dynamic> json) => Workflow(
    id: json['id'] as int,
    userId: json['user_id'] as int,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    isPublic: json['is_public'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    deletedAt: json['deleted_at'] != null
        ? DateTime.parse(json['deleted_at'] as String)
        : null,
    blockCount: json['block_count'] as int? ?? 0,
    blocks:
        (json['blocks'] as List<dynamic>?)
            ?.map((e) => WorkflowBlock.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}
