import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/progression_states_table.dart';
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
    ProgressionStatesTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Constructor used exclusively in unit tests (100% in-memory SQLite database)
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        try {
          await m.addColumn(routinesTable, routinesTable.blocksJson);
        } catch (_) {}
        try {
          await m.createTable(progressionStatesTable);
        } catch (_) {}
      }
    },
    beforeOpen: (details) async {
      try {
        await customStatement(
          "ALTER TABLE routines ADD COLUMN blocks_json TEXT NOT NULL DEFAULT '[]'",
        );
      } catch (_) {}
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'repengine.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
