import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

/// Singleton provider injecting the Drift SQLite database across the application.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // When the app or container is disposed, close the SQLite database connection
  ref.onDispose(() => db.close());
  return db;
});
