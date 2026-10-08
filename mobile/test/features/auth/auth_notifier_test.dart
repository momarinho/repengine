import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drift/native.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/core/network/server_config.dart';
import 'package:repengine_mobile/features/auth/data/auth_repository.dart';
import 'package:repengine_mobile/features/auth/domain/auth_state.dart';
import 'package:repengine_mobile/features/sync/application/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeServerConfigNotifier extends ServerConfigNotifier {
  FakeServerConfigNotifier([String host = 'http://localhost:8081']) {
    state = host;
  }
}

class FakeSyncEngine extends StateNotifier<SyncState> implements SyncEngine {
  bool syncNowCalled = false;
  bool forceFullSyncValue = false;
  bool clearSyncCacheCalled = false;

  FakeSyncEngine() : super(const SyncState());

  @override
  Future<void> clearSyncCache() async {
    clearSyncCacheCalled = true;
  }

  @override
  Future<bool> syncNow({bool forceFullSync = false}) async {
    syncNowCalled = true;
    forceFullSyncValue = forceFullSync;
    return true;
  }

  @override
  void handleHealthChange(ServerConnectionState health, bool simulateOffline) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthNotifier Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('starts as guest when no token exists in preferences', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          serverHostProvider.overrideWith((ref) => FakeServerConfigNotifier()),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );

      final notifier = AuthNotifier(
        container.read(Provider<Ref>((ref) => ref)),
        prefs: prefs,
      );

      expect(notifier.state.status, equals(AuthStatus.guest));
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.token, isNull);
    });

    test('login authenticates successfully, saves token and triggers syncNow', () async {
      final fakeSync = FakeSyncEngine();
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final mockHttp = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, equals('/api/v1/mobile/auth/login'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], equals('athlete@repengine.com'));
        expect(body['password'], equals('password123'));

        return http.Response(
          jsonEncode({
            'message': 'logged in',
            'user_id': 42,
            'token': 'signed-jwt-token-42',
          }),
          200,
        );
      });

      final container = ProviderContainer(
        overrides: [
          serverHostProvider.overrideWith((ref) => FakeServerConfigNotifier()),
          syncEngineProvider.overrideWith((ref) => fakeSync),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );

      final notifier = AuthNotifier(
        container.read(Provider<Ref>((ref) => ref)),
        client: mockHttp,
        prefs: prefs,
      );

      final success = await notifier.login(
        email: 'athlete@repengine.com',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(notifier.state.status, equals(AuthStatus.authenticated));
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.userId, equals(42));
      expect(notifier.state.token, equals('signed-jwt-token-42'));
      expect(notifier.state.email, equals('athlete@repengine.com'));

      // Check SharedPreferences persistence
      expect(prefs.getString('repengine_auth_token'), equals('signed-jwt-token-42'));
      expect(prefs.getInt('repengine_auth_user_id'), equals(42));
      expect(prefs.getString('repengine_auth_email'), equals('athlete@repengine.com'));

      // Check sync triggered with forceFullSync = true
      expect(fakeSync.syncNowCalled, isTrue);
      expect(fakeSync.forceFullSyncValue, isTrue);
    });

    test('login handles invalid credentials with error status and message', () async {
      final fakeSync = FakeSyncEngine();
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Credenciais inválidas'}),
          401,
        );
      });

      final container = ProviderContainer(
        overrides: [
          serverHostProvider.overrideWith((ref) => FakeServerConfigNotifier()),
          syncEngineProvider.overrideWith((ref) => fakeSync),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );

      final notifier = AuthNotifier(
        container.read(Provider<Ref>((ref) => ref)),
        client: mockHttp,
        prefs: prefs,
      );

      final success = await notifier.login(
        email: 'athlete@repengine.com',
        password: 'wrongpassword',
      );

      expect(success, isFalse);
      expect(notifier.state.status, equals(AuthStatus.error));
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.errorMessage, contains('Credenciais inválidas'));
      expect(fakeSync.syncNowCalled, isFalse);
    });

    test('logout clears preferences and reverts state to guest', () async {
      final fakeSync = FakeSyncEngine();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await prefs.setString('repengine_auth_token', 'token-123');
      await prefs.setInt('repengine_auth_user_id', 99);
      await prefs.setString('repengine_auth_email', 'user@example.com');

      final container = ProviderContainer(
        overrides: [
          serverHostProvider.overrideWith((ref) => FakeServerConfigNotifier()),
          syncEngineProvider.overrideWith((ref) => fakeSync),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );

      final notifier = AuthNotifier(
        container.read(Provider<Ref>((ref) => ref)),
        prefs: prefs,
      );

      // Verify loaded from prefs
      expect(notifier.state.status, equals(AuthStatus.authenticated));
      expect(notifier.state.token, equals('token-123'));

      // Perform logout
      await notifier.logout();

      expect(notifier.state.status, equals(AuthStatus.guest));
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.token, isNull);

      // Verify cleared in prefs
      expect(prefs.getString('repengine_auth_token'), isNull);
      expect(prefs.getInt('repengine_auth_user_id'), isNull);
      expect(prefs.getString('repengine_auth_email'), isNull);
    });
  });
}
