import 'package:drift/drift.dart';

@DataClassName('SyncQueueData')
class SyncQueueTable extends Table {
  @override
  String get tableName => 'sync_queue';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityClientId => text()();
  TextColumn get entityType => text()(); // 'session' | 'set_log'
  TextColumn get action => text()();     // 'CREATE' | 'UPDATE'
  TextColumn get payload => text()();    // JSON serializado
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending' | 'syncing' | 'failed'
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}
