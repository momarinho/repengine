import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/widgets/plate_calculator_sheet.dart';

void main() {
  Widget createTestWidget({required double initialLoad}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => PlateCalculatorSheet.show(context, initialLoad),
              child: const Text('Open Plate Calc'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('PlateCalculatorSheet decomposes 100kg load accurately for standard 20kg bar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(initialLoad: 100.0));
    await tester.tap(find.text('Open Plate Calc'));
    await tester.pumpAndSettle();

    // Verify Title & Hero
    expect(find.text('Plate Calculator'), findsOneWidget);
    expect(find.text('100 kg'), findsOneWidget);
    expect(find.text('EACH SIDE OF BARBELL'), findsOneWidget);
    expect(find.text('40 kg'), findsOneWidget); // (100 - 20) / 2 = 40 kg per side

    // 40 kg breakdown: 1x 25 kg + 1x 15 kg
    expect(find.text('1x  25 kg'), findsOneWidget);
    expect(find.text('1x  15 kg'), findsOneWidget);
  });

  testWidgets('PlateCalculatorSheet allows adjusting load with steppers', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(initialLoad: 100.0));
    await tester.tap(find.text('Open Plate Calc'));
    await tester.pumpAndSettle();

    // Tap +5 stepper
    await tester.tap(find.text('+5'));
    await tester.pumpAndSettle();

    // 105 kg -> 42.5 kg per side -> 1x 25kg, 1x 15kg, 1x 2.5kg
    expect(find.text('105 kg'), findsOneWidget);
    expect(find.text('42.5 kg'), findsOneWidget);
    expect(find.text('1x  25 kg'), findsOneWidget);
    expect(find.text('1x  15 kg'), findsOneWidget);
    expect(find.text('1x  2.5 kg'), findsOneWidget);
  });

  testWidgets('PlateCalculatorSheet handles empty barbell load gracefully', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(initialLoad: 20.0));
    await tester.tap(find.text('Open Plate Calc'));
    await tester.pumpAndSettle();

    expect(find.text('20 kg'), findsWidgets);
    expect(find.text('0 kg'), findsOneWidget);
    expect(find.text('Empty Barbell: No plates needed on either side.'), findsOneWidget);
  });

  testWidgets('PlateCalculatorSheet switches barbell weight chips correctly', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(initialLoad: 60.0));
    await tester.tap(find.text('Open Plate Calc'));
    await tester.pumpAndSettle();

    // Default 20kg bar: (60 - 20) / 2 = 20 kg per side (1x 20kg)
    expect(find.text('1x  20 kg'), findsOneWidget);

    // Switch to 15 kg bar (Women's Olympic bar): (60 - 15) / 2 = 22.5 kg per side (1x 20kg + 1x 2.5kg)
    await tester.tap(find.text('15 kg (Women)'));
    await tester.pumpAndSettle();

    expect(find.text('22.5 kg'), findsOneWidget);
    expect(find.text('1x  20 kg'), findsOneWidget);
    expect(find.text('1x  2.5 kg'), findsOneWidget);
  });
}
