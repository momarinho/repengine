import 'package:meta/meta.dart';

@immutable
class SyncPullRequest {
  final DateTime? lastSyncedAt;

  const SyncPullRequest({this.lastSyncedAt});

  Map<String, dynamic> toJson() => {
    if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt!.toIso8601String(),
  };

  factory SyncPullRequest.fromJson(Map<String, dynamic> json) {
    return SyncPullRequest(
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.parse(json['last_synced_at'] as String)
          : null,
    );
  }
}
