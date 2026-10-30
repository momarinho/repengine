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
  testWidgets('RepEngineApp renders AthleteAuthScreen first when unauthenticated and advances to HUD via Guest Mode', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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

    // Verify initial screen is AthleteAuthScreen
    expect(find.text('RepEngine Athlete'), findsOneWidget);
    expect(find.text('Train Offline / Guest Mode'), findsOneWidget);

    // Advance via Guest Mode
    await tester.ensureVisible(find.text('Train Offline / Guest Mode'));
    await tester.tap(find.text('Train Offline / Guest Mode'));
    await tester.pumpAndSettle();

    // Verify HUD is now shown
    expect(find.text('RepEngine HUD'), findsOneWidget);
    expect(find.text('Ready to Train?'), findsOneWidget);

    // Verify repengine_core can be imported and instantiated inside mobile
    const payload = SyncPushPayload();
    expect(payload.sessions, isEmpty);

    await db.close();
  });

  testWidgets('RepEngineApp boots directly to HUD when already authenticated in preferences', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'repengine_auth_token': 'fake_jwt_token',
      'repengine_auth_user_id': 42,
      'repengine_auth_email': 'athlete@repengine.com',
    });
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

    // Directly in HUD without showing login screen
    expect(find.text('RepEngine HUD'), findsOneWidget);
    expect(find.text('Ready to Train?'), findsOneWidget);
    expect(find.text('RepEngine Athlete'), findsNothing);

    await db.close();
  });
}
