import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';

@immutable
class RoutineExercise {
  final String blockClientId;
  final String nodeTypeSlug;
  final String name;
  final int sets;
  final String reps;
  final double targetLoad;
  final int restSeconds;

  const RoutineExercise({
    required this.blockClientId,
    required this.nodeTypeSlug,
    required this.name,
    this.sets = 3,
    this.reps = '5',
    this.targetLoad = 100.0,
    this.restSeconds = 90,
  });
}

@immutable
class RoutineSection {
  final String id;
  final String title;
  final String subtitle;
  final List<RoutineExercise> exercises;

  const RoutineSection({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.exercises = const [],
  });
}

@immutable
class ParsedRoutine {
  final int id;
  final String name;
  final String description;
  final List<RoutineSection> sections;

  const ParsedRoutine({
    required this.id,
    required this.name,
    this.description = '',
    this.sections = const [],
  });

  static ParsedRoutine fromRoutine(Routine routine) {
    List<dynamic> blockList = [];

    try {
      if (routine.blocksJson.isNotEmpty && routine.blocksJson != '[]') {
        blockList = jsonDecode(routine.blocksJson) as List<dynamic>;
      }
    } catch (_) {
      blockList = [];
    }

    if (blockList.isEmpty) {
      // Default GZCLP 4-Day Powerbuilding structure if routine has no custom blocks
      return ParsedRoutine(
        id: routine.id,
        name: routine.name.isNotEmpty ? routine.name : 'GZCLP Hybrid',
        description: routine.description.isNotEmpty
            ? routine.description
            : '4-day powerbuilding linear progression protocol',
        sections: [
          RoutineSection(
            id: 'sec_day1',
            title: 'Workout A (GZCLP Hybrid)',
            subtitle: 'Squat T1 & Bench Press T2',
            exercises: [
              const RoutineExercise(
                blockClientId: 'blk_squat',
                nodeTypeSlug: 'exercise_squat',
                name: 'Barbell Back Squat',
                sets: 5,
                reps: '5',
                targetLoad: 100.0,
                restSeconds: 180,
              ),
              const RoutineExercise(
                blockClientId: 'blk_bench_t2',
                nodeTypeSlug: 'exercise_bench',
                name: 'Bench Press (T2 Volume)',
                sets: 3,
                reps: '10',
                targetLoad: 70.0,
                restSeconds: 120,
              ),
              const RoutineExercise(
                blockClientId: 'blk_lat_pulldown',
                nodeTypeSlug: 'exercise_lat_pulldown',
                name: 'Lat Pulldown (T3 Accessory)',
                sets: 3,
                reps: '15',
                targetLoad: 45.0,
                restSeconds: 90,
              ),
            ],
          ),
          RoutineSection(
            id: 'sec_day2',
            title: 'Workout B (Deadlift & OHP)',
            subtitle: 'Overhead Press T1 & Deadlift T2',
            exercises: [
              const RoutineExercise(
                blockClientId: 'blk_ohp',
                nodeTypeSlug: 'exercise_ohp',
                name: 'Overhead Press (OHP)',
                sets: 5,
                reps: '3',
                targetLoad: 50.0,
                restSeconds: 180,
              ),
              const RoutineExercise(
                blockClientId: 'blk_deadlift_t2',
                nodeTypeSlug: 'exercise_deadlift',
                name: 'Deadlift (T2 Volume)',
                sets: 3,
                reps: '10',
                targetLoad: 110.0,
                restSeconds: 120,
              ),
              const RoutineExercise(
                blockClientId: 'blk_db_row',
                nodeTypeSlug: 'exercise_db_row',
                name: 'Dumbbell Row (T3 Accessory)',
                sets: 3,
                reps: '15',
                targetLoad: 24.0,
                restSeconds: 90,
              ),
            ],
          ),
          RoutineSection(
            id: 'sec_day3',
            title: 'Workout C (Bench & Squat)',
            subtitle: 'Bench Press T1 & Squat T2',
            exercises: [
              const RoutineExercise(
                blockClientId: 'blk_bench_t1',
                nodeTypeSlug: 'exercise_bench',
                name: 'Bench Press (T1 Heavy)',
                sets: 5,
                reps: '3',
                targetLoad: 85.0,
                restSeconds: 180,
              ),
              const RoutineExercise(
                blockClientId: 'blk_squat_t2',
                nodeTypeSlug: 'exercise_squat',
                name: 'Barbell Back Squat (T2 Volume)',
                sets: 3,
                reps: '10',
                targetLoad: 80.0,
                restSeconds: 120,
              ),
            ],
          ),
          RoutineSection(
            id: 'sec_day4',
            title: 'Workout D (Deadlift & OHP)',
            subtitle: 'Deadlift T1 & Overhead Press T2',
            exercises: [
              const RoutineExercise(
                blockClientId: 'blk_deadlift_t1',
                nodeTypeSlug: 'exercise_deadlift',
                name: 'Deadlift (T1 Heavy)',
                sets: 5,
                reps: '3',
                targetLoad: 140.0,
                restSeconds: 180,
              ),
              const RoutineExercise(
                blockClientId: 'blk_ohp_t2',
                nodeTypeSlug: 'exercise_ohp',
                name: 'Overhead Press (T2 Volume)',
                sets: 3,
                reps: '10',
                targetLoad: 40.0,
                restSeconds: 120,
              ),
            ],
          ),
        ],
      );
    }

    // Parse block list from Go Core / Web JSON
    RoutineSection? currentSection;
    final parsedSections = <RoutineSection>[];
    var currentExercises = <RoutineExercise>[];

    for (var i = 0; i < blockList.length; i++) {
      final block = blockList[i] as Map<String, dynamic>;
      final slug = block['node_type_slug']?.toString() ?? '';
      final blockId = block['id']?.toString() ?? 'blk_$i';
      final data = (block['data'] as Map<String, dynamic>?) ?? {};

      if (slug == 'section') {
        if (currentSection != null) {
          parsedSections.add(RoutineSection(
            id: currentSection.id,
            title: currentSection.title,
            subtitle: currentSection.subtitle,
            exercises: List.unmodifiable(currentExercises),
          ));
          currentExercises = [];
        }

        final title = data['title']?.toString() ??
            data['label']?.toString() ??
            'Section ${parsedSections.length + 1}';
        final subtitle = data['subtitle']?.toString() ?? '';

        currentSection = RoutineSection(
          id: blockId,
          title: title,
          subtitle: subtitle,
        );
      } else {
        // Exercise / linear_progression / timed block
        final exerciseName = data['exercise_name']?.toString() ??
            data['title']?.toString() ??
            'Exercise ${currentExercises.length + 1}';
        final sets = int.tryParse(data['sets']?.toString() ?? '') ?? 3;
        final reps = data['reps']?.toString() ?? '5';
        final load = double.tryParse(
              data['load']?.toString() ??
                  data['load_value']?.toString() ??
                  data['start_load']?.toString() ??
                  '',
            ) ??
            100.0;
        final rest = int.tryParse(data['rest_seconds']?.toString() ??
                data['rest']?.toString() ??
                '') ??
            90;

        currentExercises.add(RoutineExercise(
          blockClientId: blockId,
          nodeTypeSlug: slug.isNotEmpty ? slug : 'exercise',
          name: exerciseName,
          sets: sets,
          reps: reps,
          targetLoad: load,
          restSeconds: rest,
        ));
      }
    }

    if (currentSection != null) {
      parsedSections.add(RoutineSection(
        id: currentSection.id,
        title: currentSection.title,
        subtitle: currentSection.subtitle,
        exercises: List.unmodifiable(currentExercises),
      ));
    } else if (currentExercises.isNotEmpty) {
      // Routine had exercises without explicit sections -> wrap in single section
      parsedSections.add(RoutineSection(
        id: 'sec_root',
        title: routine.name.isNotEmpty ? routine.name : 'Full Workout',
        exercises: List.unmodifiable(currentExercises),
      ));
    }

    return ParsedRoutine(
      id: routine.id,
      name: routine.name,
      description: routine.description,
      sections: parsedSections,
    );
  }

  /// Default built-in GZCLP hybrid routine when no routines have been synced yet
  static ParsedRoutine defaultGzclp() {
    return fromRoutine(Routine(
      id: 2,
      name: 'GZCLP Hybrid 4-Day',
      description: 'Classic Tier 1/2/3 progression protocol',
      blockCount: 10,
      isPublic: true,
      updatedAt: DateTime.now().toUtc(),
      blocksJson: '[]',
    ));
  }
}
