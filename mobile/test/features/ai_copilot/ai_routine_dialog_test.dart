import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/ai_copilot/data/ai_copilot_service.dart';
import 'package:repengine_mobile/features/ai_copilot/presentation/ai_routine_dialog.dart';
import 'package:repengine_mobile/features/workout_execution/domain/routine_model.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/routine_editor_screen.dart';

class FakeAiCopilotService implements AiCopilotService {
  ParsedRoutine? routineToReturn;
  Exception? exceptionToThrow;

  @override
  Future<ParsedRoutine> generateRoutine(String prompt, {String? apiKey}) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return routineToReturn!;
  }
}

void main() {
  group('AiRoutineDialog Widget Tests', () {
    late FakeAiCopilotService fakeAiService;

    setUp(() {
      fakeAiService = FakeAiCopilotService();
    });

    testWidgets('renders dialog elements and populates prompt from suggestion chip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiCopilotServiceProvider.overrideWithValue(fakeAiService),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: AiRoutineDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Routine Generator'), findsOneWidget);
      expect(find.text('Quick Prompts:'), findsOneWidget);
      expect(find.text('4-Day Upper / Lower for hypertrophy'), findsOneWidget);

      // Tap suggestion chip
      await tester.tap(find.text('4-Day Upper / Lower for hypertrophy'));
      await tester.pumpAndSettle();

      // Verify TextField contains the suggestion
      expect(
        find.widgetWithText(TextField, '4-Day Upper / Lower for hypertrophy'),
        findsOneWidget,
      );
    });

    testWidgets('shows validation error when prompt is empty on generate', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiCopilotServiceProvider.overrideWithValue(fakeAiService),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: AiRoutineDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate Routine'));
      await tester.pumpAndSettle();

      expect(find.text('Please describe the routine you want to create.'), findsOneWidget);
    });

    testWidgets('displays error message when AI service throws exception', (
      WidgetTester tester,
    ) async {
      fakeAiService.exceptionToThrow = const AiCopilotException('API key is missing on the server.');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiCopilotServiceProvider.overrideWithValue(fakeAiService),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: AiRoutineDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('ai_prompt_field')),
        'Custom strength split',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate Routine'));
      await tester.pumpAndSettle();

      expect(find.text('API key is missing on the server.'), findsOneWidget);
    });

    testWidgets('navigates to RoutineEditorScreen on successful generation', (
      WidgetTester tester,
    ) async {
      fakeAiService.routineToReturn = const ParsedRoutine(
        id: 0,
        name: 'AI Generated Split',
        description: 'Evidence-based routine',
        sections: [
          RoutineSection(
            id: 'sec_1',
            title: 'Day 1 - Push',
            exercises: [
              RoutineExercise(
                blockClientId: 'blk_1',
                nodeTypeSlug: 'exercise_bench',
                name: 'Bench Press',
                sets: 3,
                reps: '8',
                targetLoad: 80.0,
                restSeconds: 120,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiCopilotServiceProvider.overrideWithValue(fakeAiService),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: AiRoutineDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('ai_prompt_field')),
        'Hypertrophy split',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generate Routine'));
      await tester.pumpAndSettle();

      // Verify RoutineEditorScreen is opened
      expect(find.byType(RoutineEditorScreen), findsOneWidget);
      expect(find.text('AI Routine Draft'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
    });
  });
}
