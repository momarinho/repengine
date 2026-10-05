import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/core/network/server_config.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/workout_execution_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('WorkoutExecutionScreen starts session and logs set with live UI update', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

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

    // Pula o cronômetro para cancelar o timer periódico
    await tester.tap(find.byTooltip('Pular Descanso'));
    await tester.pumpAndSettle();

    // 6. Abre o DebugSettingsDrawer pelo ícone de ajustes
    await tester.tap(find.byTooltip('Diagnóstico & Rede'));
    await tester.pumpAndSettle();

    expect(find.text('Diagnóstico & Rede'), findsOneWidget);
    expect(find.text('Endereço do PC (Host BFF)'), findsOneWidget);
    expect(find.text('Modo Academia Forçado'), findsOneWidget);
    expect(find.text('Fila SQLite (SyncQueueTable)'), findsOneWidget);

    // Fecha o Drawer
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 7. Clica em Finalizar Treino e verifica se o WorkoutSummaryDialog abre
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.text('Finalizar Sessão?'), findsOneWidget);
    expect(find.text('VOLUME TOTAL'), findsOneWidget);
    expect(find.text('SÉRIES / REPS'), findsOneWidget);
    expect(find.text('500 kg'), findsOneWidget); // 100kg x 5 = 500kg

    // Confirma a finalização
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    // 8. Volta para a tela inicial vazia
    expect(find.text('Pronto para Treinar?'), findsOneWidget);

    await db.close();
  });
}
