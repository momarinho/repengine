import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:repengine_mobile/main.dart';

void main() {
  testWidgets('RepEngineApp smoke test and repengine_core integration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RepEngineApp()));
    expect(find.text('Repengine Mobile HUD'), findsOneWidget);

    // Verify repengine_core can be imported and instantiated inside mobile
    const payload = SyncPushPayload();
    expect(payload.sessions, isEmpty);
  });
}
