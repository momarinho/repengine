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
  final String? progressionType;
  final double? progressionIncrement;
  final int? progressionMinReps;
  final int? progressionMaxReps;
  final String? progressionRule;

  // Superset A & B parameters
  final String? exerciseAName;
  final String? exerciseBName;
  final double? targetLoadA;
  final double? targetLoadB;
  final String? repsA;
  final String? repsB;
  final String? progressionTypeA;
  final String? progressionTypeB;
  final double? progressionIncrementA;
  final double? progressionIncrementB;
  final int? progressionMinRepsA;
  final int? progressionMaxRepsA;
  final int? progressionMinRepsB;
  final int? progressionMaxRepsB;

  const RoutineExercise({
    required this.blockClientId,
    required this.nodeTypeSlug,
    required this.name,
    this.sets = 3,
    this.reps = '5',
    this.targetLoad = 100.0,
    this.restSeconds = 90,
    this.progressionType,
    this.progressionIncrement,
    this.progressionMinReps,
    this.progressionMaxReps,
    this.progressionRule,
    this.exerciseAName,
    this.exerciseBName,
    this.targetLoadA,
    this.targetLoadB,
    this.repsA,
    this.repsB,
    this.progressionTypeA,
    this.progressionTypeB,
    this.progressionIncrementA,
    this.progressionIncrementB,
    this.progressionMinRepsA,
    this.progressionMaxRepsA,
    this.progressionMinRepsB,
    this.progressionMaxRepsB,
  });

  bool get isSuperset =>
      nodeTypeSlug == 'superset' || (exerciseAName != null && exerciseBName != null);

  /// Formatted target load string accounting for supersets (e.g. "0 / 35 kg" or "80 kg")
  String get formattedTargetLoad {
    if (isSuperset) {
      final a = targetLoadA ?? (targetLoad > 0 ? targetLoad : 0.0);
      final b = targetLoadB ?? 0.0;
      final strA = a % 1 == 0 ? a.toInt().toString() : a.toStringAsFixed(1);
      final strB = b % 1 == 0 ? b.toInt().toString() : b.toStringAsFixed(1);
      return '$strA / $strB kg';
    }
    final str = targetLoad % 1 == 0 ? targetLoad.toInt().toString() : targetLoad.toStringAsFixed(1);
    return '$str kg';
  }

  /// Resolves the concrete numeric target reps for set logging & progressive overload.
  /// Correctly handles rep ranges (e.g. "6-8" -> 6), double progression minimums, and numeric strings.
  int get targetRepCount {
    if (progressionMinReps != null && progressionMinReps! > 0) {
      return progressionMinReps!;
    }
    final match = RegExp(r'\d+').firstMatch(reps);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 5;
    }
    return 5;
  }
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
      } else if (slug == 'rest') {
        // Standalone rest block: updates rest time of previous exercise if available
        if (currentExercises.isNotEmpty) {
          final restSec = int.tryParse(
                data['duration']?.toString() ??
                    data['rest_seconds']?.toString() ??
                    '',
              ) ??
              90;
          final last = currentExercises.removeLast();
          currentExercises.add(RoutineExercise(
            blockClientId: last.blockClientId,
            nodeTypeSlug: last.nodeTypeSlug,
            name: last.name,
            sets: last.sets,
            reps: last.reps,
            targetLoad: last.targetLoad,
            restSeconds: restSec,
          ));
        }
      } else {
        // Exercise / linear_progression / superset / timed / repeat block
        final isSupersetBlock = slug == 'superset' ||
            (data['exercise_a_name'] != null && data['exercise_b_name'] != null);

        String exerciseName;
        String? exAName;
        String? exBName;
        double? loadA;
        double? loadB;
        String? repsA;
        String? repsB;
        String? progTypeA;
        String? progTypeB;
        double? incA;
        double? incB;
        int? minRepsA;
        int? maxRepsA;
        int? minRepsB;
        int? maxRepsB;

        if (isSupersetBlock) {
          exAName = data['exercise_a_name']?.toString().trim();
          exBName = data['exercise_b_name']?.toString().trim();
          exerciseName = '${exAName ?? "Exercise A"} + ${exBName ?? "Exercise B"}';

          repsA = data['reps_a']?.toString() ?? data['reps']?.toString();
          repsB = data['reps_b']?.toString() ?? data['reps']?.toString();

          loadA = double.tryParse(
            data['start_load_a']?.toString() ??
                data['load_value_a']?.toString() ??
                data['load_a']?.toString() ??
                '',
          );
          loadB = double.tryParse(
            data['start_load_b']?.toString() ??
                data['load_value_b']?.toString() ??
                data['load_b']?.toString() ??
                '',
          );

          progTypeA = data['progression_type_a']?.toString();
          progTypeB = data['progression_type_b']?.toString();
          incA = double.tryParse(data['increment_a']?.toString() ?? '');
          incB = double.tryParse(data['increment_b']?.toString() ?? '');
          minRepsA = int.tryParse(data['min_reps_a']?.toString() ?? '');
          maxRepsA = int.tryParse(data['max_reps_a']?.toString() ?? '');
          minRepsB = int.tryParse(data['min_reps_b']?.toString() ?? '');
          maxRepsB = int.tryParse(data['max_reps_b']?.toString() ?? '');

          if (repsA != null && (minRepsA == null || maxRepsA == null)) {
            final matchA = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(repsA);
            if (matchA != null) {
              minRepsA ??= int.tryParse(matchA.group(1)!);
              maxRepsA ??= int.tryParse(matchA.group(2)!);
              progTypeA ??= 'double';
            }
          }

          if (repsB != null && (minRepsB == null || maxRepsB == null)) {
            final matchB = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(repsB);
            if (matchB != null) {
              minRepsB ??= int.tryParse(matchB.group(1)!);
              maxRepsB ??= int.tryParse(matchB.group(2)!);
              progTypeB ??= 'double';
            }
          }
        } else if (data['exercise_name'] != null &&
            data['exercise_name'].toString().trim().isNotEmpty) {
          exerciseName = data['exercise_name'].toString().trim();
        } else if (data['title'] != null &&
            data['title'].toString().trim().isNotEmpty) {
          exerciseName = data['title'].toString().trim();
        } else {
          exerciseName = 'Exercise ${currentExercises.length + 1}';
        }

        final sets = int.tryParse(data['sets']?.toString() ?? '') ?? 3;
        final reps = isSupersetBlock && repsA != null && repsB != null
            ? '$repsA / $repsB'
            : (data['reps']?.toString() ??
                (data['reps_a'] != null && data['reps_b'] != null
                    ? '${data['reps_a']} / ${data['reps_b']}'
                    : (data['duration'] != null ? '${data['duration']}s' : '5')));

        final parsedLoad = isSupersetBlock
            ? (loadA ?? 0.0)
            : double.tryParse(
                data['load']?.toString() ??
                    data['load_value']?.toString() ??
                    data['start_load']?.toString() ??
                    data['start_load_a']?.toString() ??
                    '',
              );
        final isBodyweightOrCardio = slug.contains('timed') ||
            slug.contains('repeat') ||
            exerciseName.toLowerCase().contains('jump rope') ||
            exerciseName.toLowerCase().contains('plank') ||
            exerciseName.toLowerCase().contains('pull-up') ||
            exerciseName.toLowerCase().contains('push-up');

        final load = parsedLoad ?? (isBodyweightOrCardio ? 0.0 : 100.0);

        final rest = int.tryParse(data['rest_seconds']?.toString() ??
                data['rest']?.toString() ??
                data['duration']?.toString() ??
                '') ??
            90;

        final prog = data['progression'] as Map<String, dynamic>?;
        final progType = prog?['type']?.toString() ??
            (slug == 'linear_progression' || data['increment'] != null ? 'linear' : null);
        final progIncrement = double.tryParse(
            prog?['increment']?.toString() ?? data['increment']?.toString() ?? '');
        var minReps = int.tryParse(prog?['min_reps']?.toString() ?? '');
        var maxReps = int.tryParse(prog?['max_reps']?.toString() ?? '');
        final progRule = prog?['rule']?.toString() ??
            prog?['progression_rule']?.toString() ??
            data['progression_rule']?.toString();

        if (progType == 'double' || (minReps == null && reps.contains('-'))) {
          final rangeMatch = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(reps);
          if (rangeMatch != null) {
            minReps ??= int.tryParse(rangeMatch.group(1)!);
            maxReps ??= int.tryParse(rangeMatch.group(2)!);
          }
        }

        currentExercises.add(RoutineExercise(
          blockClientId: blockId,
          nodeTypeSlug: slug.isNotEmpty ? slug : (isSupersetBlock ? 'superset' : 'exercise'),
          name: exerciseName,
          sets: sets,
          reps: reps,
          targetLoad: load,
          restSeconds: rest,
          progressionType: progType,
          progressionIncrement: progIncrement,
          progressionMinReps: minReps,
          progressionMaxReps: maxReps,
          progressionRule: progRule,
          exerciseAName: exAName,
          exerciseBName: exBName,
          targetLoadA: loadA,
          targetLoadB: loadB,
          repsA: repsA,
          repsB: repsB,
          progressionTypeA: progTypeA,
          progressionTypeB: progTypeB,
          progressionIncrementA: incA,
          progressionIncrementB: incB,
          progressionMinRepsA: minRepsA,
          progressionMaxRepsA: maxRepsA,
          progressionMinRepsB: minRepsB,
          progressionMaxRepsB: maxRepsB,
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

/// Defensive parser for canonical RepEngine Routine JSON v1 and external AI formats
@immutable
class CanonicalRoutineImport {
  final String name;
  final String description;
  final List<RoutineSection> sections;

  const CanonicalRoutineImport({
    required this.name,
    this.description = '',
    required this.sections,
  });

  static CanonicalRoutineImport parse(String jsonString) {
    if (jsonString.trim().isEmpty) {
      throw const FormatException('JSON content is empty.');
    }

    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root JSON must be an object.');
    }

    final name = decoded['name']?.toString() ??
        decoded['routine_name']?.toString() ??
        'Imported Routine';
    final description = decoded['description']?.toString() ?? '';

    final rawSections = decoded['sections'] ?? decoded['days'];
    final sections = <RoutineSection>[];

    if (rawSections is List) {
      for (var sIdx = 0; sIdx < rawSections.length; sIdx++) {
        final secRaw = rawSections[sIdx];
        if (secRaw is! Map<String, dynamic>) continue;

        final secTitle = secRaw['title']?.toString() ?? 'Day ${sIdx + 1}';
        final secSubtitle = secRaw['subtitle']?.toString() ?? '';
        final rawBlocks = secRaw['blocks'] ?? secRaw['exercises'];
        final exercises = <RoutineExercise>[];

        if (rawBlocks is List) {
          for (var bIdx = 0; bIdx < rawBlocks.length; bIdx++) {
            final b = rawBlocks[bIdx];
            if (b is! Map<String, dynamic>) continue;

            final type = b['type']?.toString() ?? b['node_type_slug']?.toString() ?? 'exercise';
            if (type == 'rest' || type == 'section') continue;

            final isSuperset = type == 'superset' ||
                (b['exercise_a_name'] != null && b['exercise_b_name'] != null);

            String exName;
            String? exAName;
            String? exBName;
            double? loadA;
            double? loadB;
            String? repsA;
            String? repsB;
            String? progTypeA;
            String? progTypeB;
            double? incA;
            double? incB;
            int? minRepsA;
            int? maxRepsA;
            int? minRepsB;
            int? maxRepsB;

            if (isSuperset) {
              exAName = b['exercise_a_name']?.toString().trim();
              exBName = b['exercise_b_name']?.toString().trim();
              exName = '${exAName ?? "Exercise A"} + ${exBName ?? "Exercise B"}';
              repsA = b['reps_a']?.toString() ?? b['reps']?.toString();
              repsB = b['reps_b']?.toString() ?? b['reps']?.toString();
              loadA = double.tryParse(b['start_load_a']?.toString() ?? b['load_value_a']?.toString() ?? b['load_a']?.toString() ?? '');
              loadB = double.tryParse(b['start_load_b']?.toString() ?? b['load_value_b']?.toString() ?? b['load_b']?.toString() ?? '');
              progTypeA = b['progression_type_a']?.toString();
              progTypeB = b['progression_type_b']?.toString();
              incA = double.tryParse(b['increment_a']?.toString() ?? '');
              incB = double.tryParse(b['increment_b']?.toString() ?? '');
              minRepsA = int.tryParse(b['min_reps_a']?.toString() ?? '');
              maxRepsA = int.tryParse(b['max_reps_a']?.toString() ?? '');
              minRepsB = int.tryParse(b['min_reps_b']?.toString() ?? '');
              maxRepsB = int.tryParse(b['max_reps_b']?.toString() ?? '');

              if (repsA != null && (minRepsA == null || maxRepsA == null)) {
                final matchA = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(repsA);
                if (matchA != null) {
                  minRepsA ??= int.tryParse(matchA.group(1)!);
                  maxRepsA ??= int.tryParse(matchA.group(2)!);
                  progTypeA ??= 'double';
                }
              }
              if (repsB != null && (minRepsB == null || maxRepsB == null)) {
                final matchB = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(repsB);
                if (matchB != null) {
                  minRepsB ??= int.tryParse(matchB.group(1)!);
                  maxRepsB ??= int.tryParse(matchB.group(2)!);
                  progTypeB ??= 'double';
                }
              }
            } else {
              exName = b['exercise_name']?.toString() ??
                  b['name']?.toString() ??
                  'Exercise ${exercises.length + 1}';
            }

            final sets = int.tryParse(b['sets']?.toString() ?? '') ?? 3;
            final reps = isSuperset && repsA != null && repsB != null
                ? '$repsA / $repsB'
                : (b['reps']?.toString() ?? '5');
            final load = isSuperset
                ? (loadA ?? 0.0)
                : (double.tryParse(
                        b['target_load']?.toString() ??
                            b['load_value']?.toString() ??
                            b['start_load']?.toString() ??
                            b['load']?.toString() ??
                            '') ??
                    0.0);
            final rest = int.tryParse(b['rest_seconds']?.toString() ?? '') ?? 90;

            final prog = b['progression'] as Map<String, dynamic>?;
            final progType = prog?['type']?.toString();
            final progInc = double.tryParse(prog?['increment']?.toString() ?? '');
            var minR = int.tryParse(prog?['min_reps']?.toString() ?? '');
            var maxR = int.tryParse(prog?['max_reps']?.toString() ?? '');
            final rule = prog?['rule']?.toString();

            if (progType == 'double' || (minR == null && reps.contains('-'))) {
              final rangeMatch = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(reps);
              if (rangeMatch != null) {
                minR ??= int.tryParse(rangeMatch.group(1)!);
                maxR ??= int.tryParse(rangeMatch.group(2)!);
              }
            }

            exercises.add(RoutineExercise(
              blockClientId: 'blk_${sIdx}_$bIdx',
              nodeTypeSlug: type,
              name: exName,
              sets: sets,
              reps: reps,
              targetLoad: load,
              restSeconds: rest,
              progressionType: progType,
              progressionIncrement: progInc,
              progressionMinReps: minR,
              progressionMaxReps: maxR,
              progressionRule: rule,
              exerciseAName: exAName,
              exerciseBName: exBName,
              targetLoadA: loadA,
              targetLoadB: loadB,
              repsA: repsA,
              repsB: repsB,
              progressionTypeA: progTypeA,
              progressionTypeB: progTypeB,
              progressionIncrementA: incA,
              progressionIncrementB: incB,
              progressionMinRepsA: minRepsA,
              progressionMaxRepsA: maxRepsA,
              progressionMinRepsB: minRepsB,
              progressionMaxRepsB: maxRepsB,
            ));
          }
        }

        sections.add(RoutineSection(
          id: 'sec_${sIdx + 1}',
          title: secTitle,
          subtitle: secSubtitle,
          exercises: exercises,
        ));
      }
    }

    if (sections.isEmpty) {
      throw const FormatException('No valid workout days or exercises found in JSON.');
    }

    return CanonicalRoutineImport(
      name: name,
      description: description,
      sections: sections,
    );
  }

  ParsedRoutine toParsedRoutine([int id = 0]) {
    return ParsedRoutine(
      id: id,
      name: name,
      description: description,
      sections: sections,
    );
  }
}
