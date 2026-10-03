import 'package:drift/drift.dart';

@DataClassName('WorkoutSetLogData')
class WorkoutSetLogsTable extends Table {
  @override
  String get tableName => 'workout_set_logs';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientId => text().unique()();
  TextColumn get sessionClientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get blockClientId => text()();
  TextColumn get nodeTypeSlug => text()();
  IntColumn get setIndex => integer()();
  TextColumn get prescribedReps => text().withDefault(const Constant(''))();
  TextColumn get prescribedLoad => text().withDefault(const Constant(''))();
  TextColumn get actualReps => text().withDefault(const Constant(''))();
  TextColumn get actualLoad => text().withDefault(const Constant(''))();
  TextColumn get actualRpe => text().withDefault(const Constant(''))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}
