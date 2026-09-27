import 'package:meta/meta.dart';

enum SyncItemStatus { accepted, ignoredDuplicate, conflictFlagged }

@immutable
class SyncPushItemStatus {
  final String clientId;
  final SyncItemStatus status;
  final String? message;
  final int? serverId;

  const SyncPushItemStatus({
    required this.clientId,
    required this.status,
    this.message,
    this.serverId,
  });

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'status': status.name,
    if (message != null) 'message': message,
    if (serverId != null) 'server_id': serverId,
  };

  factory SyncPushItemStatus.fromJson(Map<String, dynamic> json) =>
      SyncPushItemStatus(
        clientId: json['client_id'] as String,
        status: SyncItemStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => SyncItemStatus.conflictFlagged,
        ),
        message: json['message'] as String?,
        serverId: json['server_id'] as int?,
      );
}

@immutable
class SyncPushResult {
  final List<SyncPushItemStatus> items;
  final DateTime processedAt;

  const SyncPushResult({required this.items, required this.processedAt});

  Map<String, dynamic> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
    'processed_at': processedAt.toIso8601String(),
  };

  factory SyncPushResult.fromJson(Map<String, dynamic> json) => SyncPushResult(
    items:
        (json['items'] as List<dynamic>?)
            ?.map((i) => SyncPushItemStatus.fromJson(i as Map<String, dynamic>))
            .toList() ??
        const [],
    processedAt: DateTime.parse(json['processed_at'] as String),
  );
}
