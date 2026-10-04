import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/main.dart';

void main() {
  testWidgets('RepEngineApp renders HUD and starts workout session', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const RepEngineApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RepEngine HUD'), findsOneWidget);
    expect(find.text('Pronto para Treinar?'), findsOneWidget);

    // Verify repengine_core can be imported and instantiated inside mobile
    const payload = SyncPushPayload();
    expect(payload.sessions, isEmpty);

    await db.close();
  });
}
