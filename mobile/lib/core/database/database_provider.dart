import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

/// Provider singleton que injeta o banco de dados Drift em qualquer lugar do app.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Quando o app ou container for destruído, fecha a conexão SQLite
  ref.onDispose(() => db.close());
  return db;
});
