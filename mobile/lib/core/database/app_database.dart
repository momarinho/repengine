import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/routines_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/workout_sessions_table.dart';
import 'tables/workout_set_logs_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    RoutinesTable,
    WorkoutSessionsTable,
    WorkoutSetLogsTable,
    SyncQueueTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Constructor used exclusively in unit tests (100% in-memory SQLite database)
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'repengine.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
