import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/core/network/server_config.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/workout_execution_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('WorkoutExecutionScreen starts session and logs set with live UI update', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          serverHealthProvider.overrideWith((ref) => ServerHealthNotifier(ref, autoStartTimer: false)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const WorkoutExecutionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Initial empty state
    expect(find.text('Ready to Train?'), findsOneWidget);
    expect(find.text('START WORKOUT A (GZCLP HYBRID)'), findsOneWidget);

    // 2. Start workout
    await tester.ensureVisible(find.text('START WORKOUT A (GZCLP HYBRID)'));
    await tester.tap(find.text('START WORKOUT A (GZCLP HYBRID)'));
    await tester.pumpAndSettle();

    // 3. Verify active HUD appeared
    expect(find.text('ACTIVE SESSION'), findsOneWidget);
    expect(find.text('Workout A (GZCLP Hybrid)'), findsOneWidget);
    expect(find.text('No completed sets yet.'), findsOneWidget);

    // 4. Complete a set
    expect(find.text('LOG SET (100.0 kg × 5)'), findsOneWidget);
    await tester.tap(find.text('LOG SET (100.0 kg × 5)'));
    await tester.pumpAndSettle();

    // 5. Verify set log card was added to list and rest timer opened
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('100.0 kg × 5 reps'), findsOneWidget);
    expect(find.text('REST TIMER'), findsOneWidget);

    // Skip rest timer to cancel periodic ticker
    await tester.tap(find.byTooltip('Skip Rest'));
    await tester.pumpAndSettle();

    // 6. Open DebugSettingsDrawer via action icon
    await tester.tap(find.byTooltip('Diagnostics & Network'));
    await tester.pumpAndSettle();

    expect(find.text('Diagnostics & Network'), findsOneWidget);
    expect(find.text('Conta RepEngine Web'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(find.text('Simulate Gym / Offline Mode'), findsOneWidget);
    expect(find.text('Cloud Synchronization'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('SQLite Queue (SyncQueueTable)'), findsOneWidget);

    // Close Drawer
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 7. Click Finish and verify WorkoutSummaryDialog opens
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('Finish Workout?'), findsOneWidget);
    expect(find.text('TOTAL VOLUME'), findsOneWidget);
    expect(find.text('SETS / REPS'), findsOneWidget);
    expect(find.text('500 kg'), findsOneWidget); // 100kg x 5 = 500kg

    // Confirm completion
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();

    // 8. Return to initial empty state
    expect(find.text('Ready to Train?'), findsOneWidget);

    await db.close();
  });
}
