import 'package:drift/drift.dart';

@DataClassName('WorkoutSessionData')
class WorkoutSessionsTable extends Table {
  @override
  String get tableName => 'workout_sessions';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientId => text().unique()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get workflowId => integer()();
  TextColumn get sectionId => text()();
  TextColumn get sectionTitle => text()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
