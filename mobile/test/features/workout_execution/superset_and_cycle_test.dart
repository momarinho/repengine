import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/features/workout_execution/data/workout_repository.dart';
import 'package:repengine_mobile/features/workout_execution/domain/routine_cycle_info.dart';
import 'package:repengine_mobile/features/workout_execution/domain/routine_model.dart';

void main() {
  group('RoutineCycleInfo Tests', () {
    const section1 = RoutineSection(id: 'sec_day1', title: 'Day 1 - Push');
    const section2 = RoutineSection(id: 'sec_day2', title: 'Day 2 - Pull');
    const section3 = RoutineSection(id: 'sec_day3', title: 'Day 3 - Legs');
    final sections = [section1, section2, section3];

    test('defaults to first section when session history is empty', () {
      final info = RoutineCycleInfo.calculate(
        sections: sections,
        completedSessions: [],
      );

      expect(info.nextSection?.id, equals('sec_day1'));
      expect(info.nextIndex, equals(0));
      expect(info.lastCompletedSection, isNull);
    });

    test('advances to next section when last session is completed', () {
      final session = WorkoutSessionData(
        id: 1,
        clientId: 'sess_1',
        workflowId: 10,
        sectionId: 'sec_day1',
        sectionTitle: 'Day 1 - Push',
        status: 'completed',
        startedAt: DateTime.utc(2026, 10, 28, 10, 0),
        completedAt: DateTime.utc(2026, 10, 28, 11, 0),
      );

      final info = RoutineCycleInfo.calculate(
        sections: sections,
        completedSessions: [session],
        workflowId: 10,
      );

      expect(info.lastCompletedSection?.id, equals('sec_day1'));
      expect(info.nextSection?.id, equals('sec_day2'));
      expect(info.nextIndex, equals(1));
    });

    test('cycles back to Day 1 after completing last section in routine', () {
      final session = WorkoutSessionData(
        id: 2,
        clientId: 'sess_2',
        workflowId: 10,
        sectionId: 'sec_day3',
        sectionTitle: 'Day 3 - Legs',
        status: 'completed',
        startedAt: DateTime.utc(2026, 10, 29, 10, 0),
        completedAt: DateTime.utc(2026, 10, 29, 11, 0),
      );

      final info = RoutineCycleInfo.calculate(
        sections: sections,
        completedSessions: [session],
        workflowId: 10,
      );

      expect(info.lastCompletedSection?.id, equals('sec_day3'));
      expect(info.nextSection?.id, equals('sec_day1'));
      expect(info.nextIndex, equals(0));
    });

    test('matches section by title when sectionId differs or is missing', () {
      final session = WorkoutSessionData(
        id: 3,
        clientId: 'sess_3',
        workflowId: 10,
        sectionId: 'legacy_id',
        sectionTitle: 'Day 2 - Pull',
        status: 'completed',
        startedAt: DateTime.utc(2026, 10, 30, 10, 0),
        completedAt: DateTime.utc(2026, 10, 30, 11, 0),
      );

      final info = RoutineCycleInfo.calculate(
        sections: sections,
        completedSessions: [session],
        workflowId: 10,
      );

      expect(info.lastCompletedSection?.id, equals('sec_day2'));
      expect(info.nextSection?.id, equals('sec_day3'));
      expect(info.nextIndex, equals(2));
    });
  });

  group('Superset Parsing & Progression Tests', () {
    late AppDatabase db;
    late WorkoutRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = WorkoutRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('RoutineExercise parses superset A and B independent progression parameters', () {
      final routine = Routine(
        id: 50,
        name: 'Superset Workout',
        description: 'Antagonist pairs',
        blockCount: 2,
        isPublic: true,
        updatedAt: DateTime.now().toUtc(),
        blocksJson: '''
        [
          {
            "id": "sec_arms",
            "node_type_slug": "section",
            "data": {"title": "Arm Day"}
          },
          {
            "id": "blk_superset_1",
            "node_type_slug": "superset",
            "data": {
              "exercise_a_name": "Bodyweight Dips",
              "exercise_b_name": "Incline Dumbbell Curl",
              "sets": 3,
              "reps_a": "6-8",
              "reps_b": "10-12",
              "start_load_a": 0,
              "start_load_b": 14,
              "progression_type_a": "double",
              "progression_type_b": "double",
              "increment_a": 2.5,
              "increment_b": 2.0,
              "min_reps_a": 6,
              "max_reps_a": 8,
              "min_reps_b": 10,
              "max_reps_b": 12
            }
          }
        ]
        ''',
      );

      final parsed = ParsedRoutine.fromRoutine(routine);
      expect(parsed.sections.length, equals(1));
      final exercise = parsed.sections.first.exercises.first;

      expect(exercise.isSuperset, isTrue);
      expect(exercise.name, equals('Bodyweight Dips + Incline Dumbbell Curl'));
      expect(exercise.exerciseAName, equals('Bodyweight Dips'));
      expect(exercise.exerciseBName, equals('Incline Dumbbell Curl'));
      expect(exercise.targetLoadA, equals(0.0));
      expect(exercise.targetLoadB, equals(14.0));
      expect(exercise.reps, equals('6-8 / 10-12'));
      expect(exercise.formattedTargetLoad, equals('0 / 14 kg'));
      expect(exercise.progressionMinRepsA, equals(6));
      expect(exercise.progressionMaxRepsA, equals(8));
      expect(exercise.progressionMinRepsB, equals(10));
      expect(exercise.progressionMaxRepsB, equals(12));
      expect(exercise.progressionTypeA, equals('double'));
      expect(exercise.progressionTypeB, equals('double'));
    });

    test('getSuggestedProgressionForBlock cleanly parses composite superset loads without distortion', () async {
      // Seed a synced progression state from Go Core server with composite suggestedLoad "0 kg / 35 kg"
      await db.into(db.progressionStatesTable).insert(
            ProgressionStatesTableCompanion.insert(
              id: const Value(1),
              workflowId: 50,
              blockKey: 'blk_superset_1',
              nodeTypeSlug: 'superset',
              stateType: 'double',
              outcome: 'maintain',
              suggestedLoad: const Value('0 kg / 35 kg'),
              summary: const Value('Exercise A: Target hit (maintain 0 kg). Exercise B: Increment to 35 kg.'),
              updatedAt: DateTime.now().toUtc(),
            ),
          );

      final suggestion = await repo.getSuggestedProgressionForBlock(
        'blk_superset_1',
        fallbackLoad: 0.0,
        fallbackReps: 6,
      );

      // Verify loadA is 0.0 and loadB is 35.0 (NEVER corrupted into 0.35 or 35.0 for A)
      expect(suggestion.load, equals(0.0));
      expect(suggestion.loadB, equals(35.0));
      expect(suggestion.formattedLoad, equals('0 kg / 35 kg'));
      expect(suggestion.displayText, equals('0 kg / 35 kg'));
      expect(suggestion.reasoning, contains('Exercise A: Target hit'));
    });

    test('maintaining load from previous set in active session correctly handles superset slash loads', () async {
      final session = await repo.startSession(
        clientId: 'active_sess_1',
        workflowId: 50,
        sectionId: 'sec_arms',
        sectionTitle: 'Arm Day',
        startedAt: DateTime.now().toUtc(),
      );

      // Log set 1 with composite load "12.5 kg / 20 kg" and reps "8 / 12"
      await repo.logSet(
        clientId: 'log_set_1',
        sessionClientId: session.clientId,
        blockClientId: 'blk_superset_1',
        nodeTypeSlug: 'superset',
        setIndex: 1,
        prescribedReps: '8 / 12',
        prescribedLoad: '12.5 kg / 20 kg',
        actualReps: '8 / 12',
        actualLoad: '12.5 kg / 20 kg',
        actualRpe: '8.0',
        completed: true,
        createdAt: DateTime.now().toUtc(),
      );

      final suggestion = await repo.getSuggestedProgressionForBlock(
        'blk_superset_1',
        sectionId: 'sec_arms',
        fallbackLoad: 10.0,
        fallbackReps: 8,
      );

      expect(suggestion.load, equals(12.5));
      expect(suggestion.loadB, equals(20.0));
      expect(suggestion.reps, equals(8));
      expect(suggestion.repsB, equals(12));
      expect(suggestion.displayText, equals('12.5 kg / 20 kg'));
    });
  });
}
