import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/workout_execution/data/workout_repository.dart';
import 'package:repengine_mobile/features/workout_execution/domain/routine_model.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/routine_editor_screen.dart';

void main() {
  group('RoutineEditorScreen Tests (Sprint 10)', () {
    testWidgets('Creates a new routine and persists to SQLite and sync queue', (
      WidgetTester tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = WorkoutRepository(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            workoutRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const RoutineEditorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial UI elements
      expect(find.text('Create Routine'), findsWidgets);
      expect(find.text('ROUTINE INFORMATION'), findsOneWidget);
      expect(find.text('WORKOUT DAYS / SESSIONS'), findsOneWidget);

      // Enter routine name
      await tester.enterText(
        find.widgetWithText(TextField, 'Routine Name'),
        'Upper Lower Hypertrophy',
      );
      await tester.pumpAndSettle();

      // Tap "Create Routine" button at the bottom
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Routine'));
      await tester.pumpAndSettle();

      // Verify routine saved in database
      final routines = await db.select(db.routinesTable).get();
      expect(routines.length, equals(1));
      expect(routines.first.name, equals('Upper Lower Hypertrophy'));
      expect(routines.first.blocksJson, isNotEmpty);

      // Verify sync mutation enqueued
      final outbox = await db.select(db.syncQueueTable).get();
      expect(outbox.length, equals(1));
      expect(outbox.first.entityType, equals('workflow'));
      expect(outbox.first.action, equals('CREATE'));

      await db.close();
    });

    testWidgets('Edits an existing routine and updates SQLite and sync queue', (
      WidgetTester tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = WorkoutRepository(db);

      // Seed an existing routine
      final existing = await repo.createRoutine(
        name: 'Initial Routine',
        description: 'V1 protocol',
        sections: [
          const RoutineSection(
            id: 'sec_1',
            title: 'Push Day',
            exercises: [
              RoutineExercise(
                blockClientId: 'blk_1',
                nodeTypeSlug: 'exercise_bench',
                name: 'Bench Press',
                sets: 3,
                reps: '8',
                targetLoad: 80.0,
                restSeconds: 90,
              ),
            ],
          ),
        ],
      );

      final parsed = ParsedRoutine.fromRoutine(existing);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            workoutRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: RoutineEditorScreen(routineToEdit: parsed),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Routine'), findsOneWidget);
      expect(find.text('Initial Routine'), findsOneWidget);

      // Update routine name
      await tester.enterText(
        find.widgetWithText(TextField, 'Routine Name'),
        'Initial Routine Updated',
      );
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      // Verify database updated
      final updated = await repo.getRoutineById(existing.id);
      expect(updated, isNotNull);
      expect(updated!.name, equals('Initial Routine Updated'));

      // Verify sync queue has UPDATE mutation
      final outbox = await (db.select(db.syncQueueTable)
            ..where((t) => t.action.equals('UPDATE')))
          .get();
      expect(outbox.length, equals(1));
      expect(outbox.first.entityClientId, equals('routine-${existing.id}'));

      await db.close();
    });

    testWidgets('Deletes an existing routine via AppBar trash icon', (
      WidgetTester tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = WorkoutRepository(db);

      // Seed an existing routine
      final routine = await repo.createRoutine(
        name: 'Routine to Delete',
        description: 'Temporary',
        sections: [
          const RoutineSection(
            id: 'sec_del',
            title: 'Full Body',
            exercises: [
              RoutineExercise(
                blockClientId: 'blk_del',
                nodeTypeSlug: 'exercise_squat',
                name: 'Squat',
                sets: 3,
                reps: '5',
                targetLoad: 100.0,
                restSeconds: 120,
              ),
            ],
          ),
        ],
      );

      final parsed = ParsedRoutine.fromRoutine(routine);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            workoutRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: RoutineEditorScreen(routineToEdit: parsed),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap trash icon
      await tester.tap(find.byTooltip('Delete Routine'));
      await tester.pumpAndSettle();

      // Confirmation dialog opens
      expect(find.text('Delete Routine'), findsWidgets);
      expect(find.textContaining('Are you sure you want to delete'), findsOneWidget);

      // Tap Delete button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      // Verify database has no routines
      final routines = await db.select(db.routinesTable).get();
      expect(routines.isEmpty, isTrue);

      // Verify sync queue has DELETE mutation
      final outbox = await (db.select(db.syncQueueTable)
            ..where((t) => t.action.equals('DELETE')))
          .get();
      expect(outbox.length, equals(1));
      expect(outbox.first.entityClientId, equals('routine-${routine.id}'));

      await db.close();
    });
  });
}
