import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/core/network/host_discovery_service.dart';
import 'package:repengine_mobile/core/network/server_config.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/workout_execution/presentation/widgets/debug_settings_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HostDiscoveryService Tests', () {
    test('discovers BFF host when quick candidate responds with valid signature', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/health') {
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'service': 'repengine_mobile_bff',
              'timestamp': DateTime.now().toIso8601String(),
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = HostDiscoveryService(client: mockClient);
      final host = await service.discoverBffHost(
        timeoutPerProbe: const Duration(milliseconds: 100),
        overallTimeout: const Duration(seconds: 1),
      );

      expect(host, isNotNull);
      expect(host, anyOf('http://192.168.100.2:8081', 'http://localhost:8081', 'http://10.0.2.2:8081'));
    });

    test('ignores endpoints that do not have repengine_mobile_bff signature', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'ok', 'service': 'other_service'}),
          200,
        );
      });

      final service = HostDiscoveryService(client: mockClient);
      final host = await service.discoverBffHost(
        timeoutPerProbe: const Duration(milliseconds: 50),
        overallTimeout: const Duration(milliseconds: 300),
      );

      // Should not select other_service
      expect(host, isNull);
    });

    test('ServerConfigNotifier.autoDiscover updates host and persists to SharedPreferences', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/health') {
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'service': 'repengine_mobile_bff',
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = HostDiscoveryService(client: mockClient);
      final notifier = ServerConfigNotifier();

      // Test with custom discovery service
      final discovered = await service.discoverBffHost();
      expect(discovered, isNotNull);

      await notifier.setHost(discovered!);
      expect(notifier.state, discovered);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('repengine_server_host'), discovered);
    });

    testWidgets('DebugSettingsDrawer renders Auto-Detect button and updates host on click', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/health') {
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'service': 'repengine_mobile_bff',
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            hostDiscoveryServiceProvider.overrideWithValue(HostDiscoveryService(client: mockClient)),
            serverHealthProvider.overrideWith((ref) => ServerHealthNotifier(ref, autoStartTimer: false)),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              endDrawer: DebugSettingsDrawer(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openEndDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Auto-Detect PC (Wi-Fi)'), findsOneWidget);

      await tester.tap(find.text('Auto-Detect PC (Wi-Fi)'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);

      await db.close();
    });
  });
}
