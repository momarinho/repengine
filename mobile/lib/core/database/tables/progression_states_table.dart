import 'package:drift/drift.dart';

@DataClassName('ProgressionStateRow')
class ProgressionStatesTable extends Table {
  @override
  String get tableName => 'progression_states';

  // ID from Go Core (PostgreSQL)
  IntColumn get id => integer()();
  IntColumn get workflowId => integer()();
  IntColumn get workflowBlockId => integer().nullable()();
  TextColumn get blockKey => text()();
  TextColumn get nodeTypeSlug => text()();
  TextColumn get stateType => text()();
  TextColumn get exerciseName => text().nullable()();
  TextColumn get outcome => text()();
  TextColumn get currentLoad => text().nullable()();
  TextColumn get suggestedLoad => text().nullable()();
  IntColumn get currentWeek => integer().nullable()();
  IntColumn get suggestedWeek => integer().nullable()();
  TextColumn get summary => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
