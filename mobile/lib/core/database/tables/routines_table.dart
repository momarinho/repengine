import 'package:drift/drift.dart';

@DataClassName('Routine')
class RoutinesTable extends Table {
  @override
  String get tableName => 'routines';

  // ID from Go Core (PostgreSQL)
  IntColumn get id => integer()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get blockCount => integer().withDefault(const Constant(0))();
  BoolColumn get isPublic => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
