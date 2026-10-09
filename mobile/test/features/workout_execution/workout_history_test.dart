import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/workout_execution/data/workout_repository.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/workout_history_screen.dart';

void main() {
  testWidgets('WorkoutHistoryScreen displays empty state when there are no completed sessions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const WorkoutHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workout History'), findsOneWidget);
    expect(find.text('No Completed Workouts'), findsOneWidget);
    expect(
      find.text('When you finish a workout, your duration, volume, and sets will be recorded here automatically.'),
      findsOneWidget,
    );

    await db.close();
  });

  testWidgets('WorkoutHistoryScreen renders completed session cards with volume and expands set details', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = WorkoutRepository(db);

    final startTime = DateTime.utc(2026, 10, 9, 10, 0);
    final endTime = DateTime.utc(2026, 10, 9, 10, 45); // 45 min

    // 1. Start session
    await repo.startSession(
      clientId: 'sess-test-1',
      workflowId: 1,
      sectionId: 'sec-1',
      sectionTitle: 'Heavy Upper Body',
      startedAt: startTime,
    );

    // 2. Log two sets: 100kg x 5 (500kg), 100kg x 5 (500kg) -> total 1000kg
    await repo.logSet(
      clientId: 'set-1',
      sessionClientId: 'sess-test-1',
      blockClientId: 'blk-1',
      nodeTypeSlug: 'Barbell Bench Press',
      setIndex: 1,
      prescribedReps: '5',
      prescribedLoad: '100.0',
      actualReps: '5',
      actualLoad: '100.0',
      actualRpe: '8.5',
      completed: true,
      createdAt: startTime.add(const Duration(minutes: 5)),
    );

    await repo.logSet(
      clientId: 'set-2',
      sessionClientId: 'sess-test-1',
      blockClientId: 'blk-1',
      nodeTypeSlug: 'Barbell Bench Press',
      setIndex: 2,
      prescribedReps: '5',
      prescribedLoad: '100.0',
      actualReps: '5',
      actualLoad: '100.0',
      actualRpe: '9.0',
      completed: true,
      createdAt: startTime.add(const Duration(minutes: 10)),
    );

    // 3. Complete session
    await repo.completeSession('sess-test-1', completedAt: endTime);

    // Pump screen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const WorkoutHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header summary
    expect(find.text('1 Workout Completed'), findsOneWidget);

    // Verify session card details
    expect(find.text('Heavy Upper Body'), findsOneWidget);
    expect(find.text('45m'), findsOneWidget); // Duration
    expect(find.text('1000 kg'), findsOneWidget); // Total volume (2 x 5 x 100)
    expect(find.text('2 / 2 sets'), findsOneWidget); // Completed sets

    // Expand card to see sets
    await tester.tap(find.text('Heavy Upper Body'));
    await tester.pumpAndSettle();

    // Verify expanded set breakdown
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Set 1'), findsOneWidget);
    expect(find.text('Set 2'), findsOneWidget);
    expect(find.text('100.0 kg × 5'), findsNWidgets(2));
    expect(find.text('@ RPE 8.5'), findsOneWidget);
    expect(find.text('@ RPE 9.0'), findsOneWidget);

    await db.close();
  });

  testWidgets('WorkoutHistoryScreen deletes session when confirmed', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = WorkoutRepository(db);

    await repo.startSession(
      clientId: 'sess-to-delete',
      workflowId: 1,
      sectionId: 'sec-1',
      sectionTitle: 'Session To Delete',
      startedAt: DateTime.now().toUtc(),
    );
    await repo.completeSession('sess-to-delete', completedAt: DateTime.now().toUtc());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const WorkoutHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Session To Delete'), findsOneWidget);

    // Tap delete button
    await tester.tap(find.byTooltip('Delete Workout'));
    await tester.pumpAndSettle();

    // Confirm dialog appears
    expect(find.text('Delete Workout?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    // Verify session is deleted and empty state shows
    expect(find.text('Session To Delete'), findsNothing);
    expect(find.text('No Completed Workouts'), findsOneWidget);

    await db.close();
  });
}
