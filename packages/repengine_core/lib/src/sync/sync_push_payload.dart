import 'package:meta/meta.dart';

import '../models/workout_session.dart';
import '../models/workout_set_log.dart';

@immutable
class SyncPushPayload {
  final List<WorkoutSession> sessions;
  final List<WorkoutSetLog> setLogs;

  const SyncPushPayload({this.sessions = const [], this.setLogs = const []});

  Map<String, dynamic> toJson() => {
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'set_logs': setLogs.map((l) => l.toJson()).toList(),
  };

  factory SyncPushPayload.fromJson(Map<String, dynamic> json) {
    return SyncPushPayload(
      sessions:
          (json['sessions'] as List<dynamic>?)
              ?.map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      setLogs:
          (json['set_logs'] as List<dynamic>?)
              ?.map((e) => WorkoutSetLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
