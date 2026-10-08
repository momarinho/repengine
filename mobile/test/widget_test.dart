import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/core/network/server_config.dart';
import 'package:repengine_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RepEngineApp renders HUD and starts workout session', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          serverHealthProvider.overrideWith((ref) => ServerHealthNotifier(ref, autoStartTimer: false)),
        ],
        child: const RepEngineApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RepEngine HUD'), findsOneWidget);
    expect(find.text('Ready to Train?'), findsOneWidget);

    // Verify repengine_core can be imported and instantiated inside mobile
    const payload = SyncPushPayload();
    expect(payload.sessions, isEmpty);

    await db.close();
  });
}
