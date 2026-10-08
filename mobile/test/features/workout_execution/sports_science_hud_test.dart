import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/widgets/set_log_card.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/widgets/thumb_zone_pad.dart';

void main() {
  group('Sports Science HUD Integration (Sprint 4.1)', () {
    testWidgets('ThumbZonePad calculates and displays Consensus 1RM in real time with RPE adjustment', (
      WidgetTester tester,
    ) async {
      double? loggedLoad;
      int? loggedReps;
      double? loggedRpe;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ThumbZonePad(
              exerciseName: 'Bench Press',
              initialLoad: 100.0,
              initialReps: 5,
              initialRpe: 8.0,
              onLogSet: (load, reps, rpe) {
                loggedLoad = load;
                loggedReps = reps;
                loggedRpe = rpe;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 100kg x 5 reps @ RPE 8 -> effective reps = 7 -> Consensus 1RM = 122.5 kg
      final expectedInitial = OneRepMaxCalculator.calculate(
        exerciseName: 'Bench Press',
        load: 100.0,
        reps: 5,
        rpe: 8.0,
      );
      expect(
        find.text('Consensus 1RM: ${expectedInitial.consensus1RM.toStringAsFixed(1)} kg'),
        findsOneWidget,
      );
      expect(
        find.text('(±${expectedInitial.stdDev.toStringAsFixed(1)} kg)'),
        findsOneWidget,
      );

      // Adjust load (+5kg)
      await tester.tap(find.text('+5'));
      await tester.pumpAndSettle();

      final expectedAfterLoad = OneRepMaxCalculator.calculate(
        exerciseName: 'Bench Press',
        load: 105.0,
        reps: 5,
        rpe: 8.0,
      );
      expect(
        find.text('Consensus 1RM: ${expectedAfterLoad.consensus1RM.toStringAsFixed(1)} kg'),
        findsOneWidget,
      );

      // Change RPE to 10.0
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();

      final expectedAfterRpe = OneRepMaxCalculator.calculate(
        exerciseName: 'Bench Press',
        load: 105.0,
        reps: 5,
        rpe: 10.0,
      );
      expect(
        find.text('Consensus 1RM: ${expectedAfterRpe.consensus1RM.toStringAsFixed(1)} kg'),
        findsOneWidget,
      );

      // Log set and verify passed parameters
      expect(find.text('LOG SET (105.0 kg × 5)'), findsOneWidget);
      await tester.tap(find.text('LOG SET (105.0 kg × 5)'));
      await tester.pumpAndSettle();

      expect(loggedLoad, 105.0);
      expect(loggedReps, 5);
      expect(loggedRpe, 10.0);
    });

    testWidgets('SetLogCard displays 1RM using Scientific Consensus from repengine_core', (
      WidgetTester tester,
    ) async {
      final log = WorkoutSetLogData(
        id: 1,
        clientId: 'log-1',
        sessionClientId: 'session-1',
        blockClientId: 'blk_bench',
        nodeTypeSlug: 'exercise_bench',
        setIndex: 1,
        prescribedReps: '5',
        prescribedLoad: '100.0',
        actualReps: '5',
        actualLoad: '100.0',
        actualRpe: '8.0',
        completed: true,
        createdAt: DateTime.now().toUtc(),
      );

      final expectedResult = OneRepMaxCalculator.calculate(
        exerciseName: 'exercise_bench',
        load: 100.0,
        reps: 5,
        rpe: 8.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SetLogCard(log: log),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('100.0 kg × 5 reps'), findsOneWidget);
      expect(
        find.text('1RM: ${expectedResult.consensus1RM.toStringAsFixed(1)} kg'),
        findsOneWidget,
      );
      expect(find.text('• RPE 8.0'), findsOneWidget);
    });
  });
}
