import 'package:flutter_test/flutter_test.dart';
import 'package:repengine_core/repengine_core.dart';
import 'package:repengine_mobile/main.dart';

void main() {
  testWidgets('MainApp smoke test and repengine_core integration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MainApp());
    expect(find.text('Hello World!'), findsOneWidget);

    // Verify repengine_core can be imported and instantiated inside mobile
    const payload = SyncPushPayload();
    expect(payload.sessions, isEmpty);
  });
}
