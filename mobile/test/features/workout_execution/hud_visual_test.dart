import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/core/network/server_config.dart';
import 'package:repengine_mobile/core/theme/app_colors.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/workout_execution/data/workout_repository.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/widgets/circular_rest_timer.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/widgets/set_log_card.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/widgets/thumb_zone_pad.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/workout_execution_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Visual & Theme Regression Tests (HUD & Design System)', () {
    testWidgets('AppTheme defines correct Kanagawa Dark Palette color tokens', (
      WidgetTester tester,
    ) async {
      final theme = AppTheme.darkTheme;

      expect(theme.scaffoldBackgroundColor, equals(AppColors.background));
      expect(theme.colorScheme.primary, equals(AppColors.primary));
      expect(theme.colorScheme.primaryContainer, equals(AppColors.primaryContainer));
      expect(theme.colorScheme.surface, equals(AppColors.surface));
      expect(theme.colorScheme.onSurface, equals(AppColors.onSurface));
      expect(theme.colorScheme.outlineVariant, equals(AppColors.outlineVariant));
    });

    testWidgets('ThumbZonePad adheres to thumb-first ergonomics and visual hierarchy', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: ThumbZonePad(
                exerciseName: 'Barbell Back Squat',
                initialLoad: 120.0,
                initialReps: 5,
                progressionNote: 'Progressive overload +2.5kg recommended',
                onLogSet: (_, _, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify typography and visual hierarchy
      expect(find.text('BARBELL BACK SQUAT'), findsOneWidget);
      expect(find.text('Progressive overload +2.5kg recommended'), findsOneWidget);
      expect(find.text('LOG SET (120.0 kg × 5)'), findsOneWidget);

      // 2. Verify large primary tap target button geometry
      final logSetBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(logSetBtn.style?.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));

      // 3. Increment load and verify instant visual update
      await tester.tap(find.text('+2.5'));
      await tester.pumpAndSettle();
      expect(find.text('LOG SET (122.5 kg × 5)'), findsOneWidget);

      // 4. Increment reps and verify instant visual update
      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();
      expect(find.text('LOG SET (122.5 kg × 6)'), findsOneWidget);
    });

    testWidgets('SetLogCard renders completed set with calculated 1RM and status badge', (
      WidgetTester tester,
    ) async {
      final logData = WorkoutSetLogData(
        id: 1,
        clientId: 'log-1',
        sessionClientId: 'sess-1',
        blockClientId: 'blk_1',
        nodeTypeSlug: 'exercise_squat',
        setIndex: 1,
        actualLoad: '100.0',
        actualReps: '5',
        actualRpe: '8.0',
        prescribedLoad: '100.0',
        prescribedReps: '5',
        completed: true,
        createdAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SetLogCard(log: logData),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('100.0 kg × 5 reps'), findsOneWidget);
      expect(find.text('• RPE 8.0'), findsOneWidget);
      // 1RM consensus for 100kg x 5 @ RPE 8 (~124.6kg)
      expect(find.textContaining('1RM:'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('CircularRestTimerWidget displays countdown with controls', (
      WidgetTester tester,
    ) async {
      bool dismissed = false;
      bool finished = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CircularRestTimerWidget(
              totalSeconds: 90,
              onFinished: () => finished = true,
              onDismissed: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REST TIMER'), findsOneWidget);
      expect(find.text('01:30'), findsOneWidget);
      expect(find.text('+30s'), findsOneWidget);
      expect(find.byTooltip('Skip Rest'), findsOneWidget);

      // Add 30 seconds
      await tester.tap(find.text('+30s'));
      await tester.pumpAndSettle();
      expect(find.text('02:00'), findsOneWidget);

      // Skip rest
      await tester.tap(find.byTooltip('Skip Rest'));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
      expect(finished, isFalse);
    });

    testWidgets('Full WorkoutExecutionScreen renders with standard mobile dimensions', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400); // 1080x2400 px (Android flagship)
      tester.view.devicePixelRatio = 2.625;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = WorkoutRepository(db);

      await repo.startSession(
        clientId: 'sess-visual-1',
        workflowId: 2,
        sectionId: 'sec_day1',
        sectionTitle: 'Workout A (GZCLP Hybrid)',
        startedAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            serverHealthProvider.overrideWith(
              (ref) => ServerHealthNotifier(ref, autoStartTimer: false),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const WorkoutExecutionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RepEngine HUD'), findsOneWidget);
      expect(find.text('ACTIVE SESSION'), findsOneWidget);
      expect(find.text('Workout A (GZCLP Hybrid)'), findsOneWidget);
      expect(find.text('COMPLETED SETS'), findsOneWidget);
      expect(find.text('No completed sets yet.'), findsOneWidget);
      expect(find.byType(ThumbZonePad), findsOneWidget);

      await db.close();
    });
  });
}
