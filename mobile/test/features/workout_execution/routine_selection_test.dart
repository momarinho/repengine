import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/core/network/server_config.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/workout_execution/data/workout_repository.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/workout_execution_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Athlete can select synced routine, switch days, and launch HUD for selected day', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = WorkoutRepository(db);

    // Seed 2 custom synced workflows from Coach
    final customWorkflow = Workflow(
      id: 42,
      userId: 1,
      name: 'Push Pull Legs (PPL)',
      description: 'Hypertrophy 3-day split',
      isPublic: true,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      blockCount: 4,
      blocks: [
        const WorkflowBlock(
          id: 101,
          workflowId: 42,
          nodeTypeSlug: 'section',
          position: 1,
          data: {'title': 'Push Day (Peito/Tríceps)', 'subtitle': 'Heavy Chest & Triceps'},
        ),
        const WorkflowBlock(
          id: 102,
          workflowId: 42,
          nodeTypeSlug: 'exercise_bench',
          position: 2,
          data: {'exercise_name': 'Incline Dumbbell Press', 'sets': 4, 'reps': '8-10', 'load': 32.0, 'rest_seconds': 120},
        ),
        const WorkflowBlock(
          id: 103,
          workflowId: 42,
          nodeTypeSlug: 'section',
          position: 3,
          data: {'title': 'Pull Day (Costas/Bíceps)', 'subtitle': 'Back & Biceps hypertrophy'},
        ),
        const WorkflowBlock(
          id: 104,
          workflowId: 42,
          nodeTypeSlug: 'exercise_row',
          position: 4,
          data: {'exercise_name': 'Barbell Bent Over Row', 'sets': 3, 'reps': '10', 'load': 70.0, 'rest_seconds': 90},
        ),
      ],
    );

    await repo.upsertWorkflows([customWorkflow]);

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

    // 1. Verify routine dashboard is displayed with custom routine
    expect(find.text('Ready to Train?'), findsOneWidget);
    expect(find.text('Push Day (Peito/Tríceps)'), findsWidgets);
    expect(find.text('Pull Day (Costas/Bíceps)'), findsOneWidget);
    expect(find.text('Incline Dumbbell Press'), findsOneWidget);

    // 2. Select Pull Day
    await tester.tap(find.text('Pull Day (Costas/Bíceps)').first);
    await tester.pumpAndSettle();

    // Verify Pull Day exercises are visible
    expect(find.text('Barbell Bent Over Row'), findsOneWidget);
    expect(find.text('START PULL DAY (COSTAS/BÍCEPS)'), findsOneWidget);

    // 3. Start workout on Pull Day
    await tester.tap(find.text('START PULL DAY (COSTAS/BÍCEPS)'));
    await tester.pumpAndSettle();

    // 4. Verify HUD started with Pull Day
    expect(find.text('ACTIVE SESSION'), findsOneWidget);
    expect(find.text('Pull Day (Costas/Bíceps)'), findsOneWidget);
    expect(find.text('LOG SET (70.0 kg × 10)'), findsOneWidget);

    // 5. Log set
    await tester.tap(find.text('LOG SET (70.0 kg × 10)'));
    await tester.pumpAndSettle();

    expect(find.text('#1'), findsOneWidget);
    expect(find.text('70.0 kg × 10 reps'), findsOneWidget);

    await tester.tap(find.byTooltip('Skip Rest'));
    await tester.pumpAndSettle();

    await db.close();
  });

  testWidgets('Athlete can switch between multiple exercises within active workout session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = WorkoutRepository(db);

    // Seed routine with 1 section containing 2 exercises
    final multiExerciseWorkflow = Workflow(
      id: 88,
      userId: 1,
      name: 'Full Body A',
      isPublic: true,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      blockCount: 3,
      blocks: [
        const WorkflowBlock(
          id: 201,
          workflowId: 88,
          nodeTypeSlug: 'section',
          position: 1,
          data: {'title': 'Full Body Day 1'},
        ),
        const WorkflowBlock(
          id: 202,
          workflowId: 88,
          nodeTypeSlug: 'exercise_squat',
          position: 2,
          data: {'exercise_name': 'Barbell Squat', 'sets': 3, 'reps': '5', 'load': 100.0, 'rest_seconds': 120},
        ),
        const WorkflowBlock(
          id: 203,
          workflowId: 88,
          nodeTypeSlug: 'exercise_bench',
          position: 3,
          data: {'exercise_name': 'Flat Bench Press', 'sets': 3, 'reps': '8', 'load': 80.0, 'rest_seconds': 90},
        ),
      ],
    );

    await repo.upsertWorkflows([multiExerciseWorkflow]);

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

    // Start workout
    await tester.tap(find.text('START FULL BODY DAY 1'));
    await tester.pumpAndSettle();

    // In HUD: verify exercise tabs/chips are displayed
    expect(find.text('Barbell Squat'), findsWidgets);
    expect(find.text('Flat Bench Press'), findsOneWidget);

    // First exercise is Barbell Squat: log set
    expect(find.text('LOG SET (100.0 kg × 5)'), findsOneWidget);
    await tester.tap(find.text('LOG SET (100.0 kg × 5)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Skip Rest'));
    await tester.pumpAndSettle();

    // Switch to second exercise: Flat Bench Press
    await tester.tap(find.text('Flat Bench Press'));
    await tester.pumpAndSettle();

    // Verify ThumbZonePad switched to Bench Press
    expect(find.text('LOG SET (80.0 kg × 8)'), findsOneWidget);
    await tester.tap(find.text('LOG SET (80.0 kg × 8)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Skip Rest'));
    await tester.pumpAndSettle();

    // Verify both sets are listed
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('100.0 kg × 5 reps'), findsOneWidget);
    expect(find.text('80.0 kg × 8 reps'), findsOneWidget);

    await db.close();
  });

  testWidgets('Athlete completing all sets of an exercise triggers rest timer and auto-advances to next exercise, and completing all exercises shows finished state', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = WorkoutRepository(db);

    // Seed routine with 1 section containing 2 exercises (2 sets each)
    final workflow = Workflow(
      id: 99,
      userId: 1,
      name: 'Upper Body Blast',
      isPublic: true,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      blockCount: 3,
      blocks: [
        const WorkflowBlock(
          id: 301,
          workflowId: 99,
          nodeTypeSlug: 'section',
          position: 1,
          data: {'title': 'Upper Body Focus'},
        ),
        const WorkflowBlock(
          id: 302,
          workflowId: 99,
          nodeTypeSlug: 'exercise_ohp',
          position: 2,
          data: {'exercise_name': 'Barbell Overhead Press', 'sets': 2, 'reps': '5', 'load': 50.0, 'rest_seconds': 60},
        ),
        const WorkflowBlock(
          id: 303,
          workflowId: 99,
          nodeTypeSlug: 'exercise_deadlift',
          position: 3,
          data: {'exercise_name': 'Deadlift', 'sets': 2, 'reps': '5', 'load': 120.0, 'rest_seconds': 90},
        ),
      ],
    );

    await repo.upsertWorkflows([workflow]);

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

    // Start workout
    await tester.tap(find.text('START UPPER BODY FOCUS'));
    await tester.pumpAndSettle();

    // Verify first exercise is active
    expect(find.text('Barbell Overhead Press'), findsWidgets);
    expect(find.text('Deadlift'), findsOneWidget);
    expect(find.text('LOG SET (50.0 kg × 5)'), findsOneWidget);

    // 1. Log set 1 of OHP (1/2 sets)
    await tester.tap(find.text('LOG SET (50.0 kg × 5)'));
    await tester.pumpAndSettle();

    // Rest timer starts, exercise is still OHP (1/2 done)
    expect(find.text('REST TIMER'), findsOneWidget);
    await tester.tap(find.byTooltip('Skip Rest'));
    await tester.pumpAndSettle();

    expect(find.text('LOG SET (50.0 kg × 5)'), findsOneWidget);

    // 2. Log set 2 of OHP (2/2 sets - completed!)
    await tester.tap(find.text('LOG SET (50.0 kg × 5)'));
    await tester.pumpAndSettle();

    // Rest timer starts automatically
    expect(find.text('REST TIMER'), findsOneWidget);
    await tester.tap(find.byTooltip('Skip Rest'));
    await tester.pumpAndSettle();

    // Verify automatic advancement to Deadlift!
    // ThumbZonePad should now show Deadlift's target load (120.0 kg x 5)
    expect(find.text('LOG SET (120.0 kg × 5)'), findsOneWidget);

    // If athlete taps back on Barbell Overhead Press chip:
    await tester.tap(find.text('Barbell Overhead Press').first);
    await tester.pumpAndSettle();

    // It should display ExerciseCompletedPad, NOT ThumbZonePad!
    expect(find.text('BARBELL OVERHEAD PRESS COMPLETED (2/2)'), findsOneWidget);
    expect(find.text('NEXT: DEADLIFT'), findsOneWidget);
    expect(find.text('LOG SET (50.0 kg × 5)'), findsNothing);

    // Tapping "NEXT: DEADLIFT" returns to Deadlift
    await tester.tap(find.text('NEXT: DEADLIFT'));
    await tester.pumpAndSettle();
    expect(find.text('LOG SET (120.0 kg × 5)'), findsOneWidget);

    // 3. Log set 1 of Deadlift
    await tester.tap(find.text('LOG SET (120.0 kg × 5)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Skip Rest'));
    await tester.pumpAndSettle();

    // 4. Log set 2 of Deadlift (Final set of the whole workout!)
    await tester.tap(find.text('LOG SET (120.0 kg × 5)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Skip Rest'));
    await tester.pumpAndSettle();

    // All exercises are done!
    // Should display ExerciseCompletedPad with "ALL EXERCISES COMPLETED!"
    expect(find.text('ALL EXERCISES COMPLETED!'), findsOneWidget);
    expect(find.text('REVIEW & FINISH WORKOUT'), findsOneWidget);

    // Tapping "REVIEW & FINISH WORKOUT" opens the summary dialog
    await tester.tap(find.text('REVIEW & FINISH WORKOUT'));
    await tester.pumpAndSettle();

    expect(find.text('Finish Workout?'), findsOneWidget);
    expect(find.text('SETS / REPS'), findsOneWidget);
    expect(find.text('4 / 20'), findsOneWidget);

    // Confirm completion
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();

    // UI returns to ready state
    expect(find.text('Ready to Train?'), findsOneWidget);

    await db.close();
  });
}

