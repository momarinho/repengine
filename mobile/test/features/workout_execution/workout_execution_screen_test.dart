import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/workout_execution_screen.dart';

void main() {
  testWidgets('WorkoutExecutionScreen starts session and logs set with live UI update', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const WorkoutExecutionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Estado inicial: vazio
    expect(find.text('Pronto para Treinar?'), findsOneWidget);
    expect(find.text('INICIAR TREINO A (GZCLP HYBRID)'), findsOneWidget);

    // 2. Inicia o treino
    await tester.tap(find.text('INICIAR TREINO A (GZCLP HYBRID)'));
    await tester.pumpAndSettle();

    // 3. Verifica se a tela do HUD ativo apareceu
    expect(find.text('SESSÃO ATIVA'), findsOneWidget);
    expect(find.text('Treino A (GZCLP Hybrid)'), findsOneWidget);
    expect(find.text('Nenhuma série concluída ainda.'), findsOneWidget);

    // 4. Conclui uma série
    expect(find.text('CONCLUIR SÉRIE (100.0 kg × 5)'), findsOneWidget);
    await tester.tap(find.text('CONCLUIR SÉRIE (100.0 kg × 5)'));
    await tester.pumpAndSettle();

    // 5. Verifica se o card da série foi adicionado na lista e o cronômetro abriu
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('100.0 kg × 5 reps'), findsOneWidget);
    expect(find.text('TEMPO DE DESCANSO'), findsOneWidget);

    await db.close();
  });
}
