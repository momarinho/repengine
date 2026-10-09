import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:repengine_mobile/core/database/app_database.dart';
import 'package:repengine_mobile/core/database/database_provider.dart';
import 'package:repengine_mobile/core/network/server_config.dart';
import 'package:repengine_mobile/core/theme/app_theme.dart';
import 'package:repengine_mobile/features/auth/data/auth_repository.dart';
import 'package:repengine_mobile/features/auth/domain/auth_state.dart';
import 'package:repengine_mobile/features/auth/presentation/athlete_auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AthleteAuthScreen Tests (Sprint 10)', () {
    testWidgets('renders login form and guest mode button when unauthenticated', (
      WidgetTester tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            serverHealthProvider.overrideWith(
              (ref) => ServerHealthNotifier(ref, autoStartTimer: false),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AthleteAuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RepEngine Athlete'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Log In & Sync'), findsOneWidget);
      expect(find.text('Train Offline / Guest Mode'), findsOneWidget);

      await db.close();
    });

    testWidgets('renders athlete profile card when authenticated', (
      WidgetTester tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            serverHealthProvider.overrideWith(
              (ref) => ServerHealthNotifier(ref, autoStartTimer: false),
            ),
            authStateProvider.overrideWith(
              (ref) => FakeAuthNotifier(
                const AuthState(
                  status: AuthStatus.authenticated,
                  token: 'jwt-fake-token',
                  userId: 99,
                  email: 'coach_athlete@repengine.com',
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AthleteAuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Athlete Profile'), findsOneWidget);
      expect(find.text('coach_athlete@repengine.com'), findsOneWidget);
      expect(find.text('RepEngine ID: #99'), findsOneWidget);
      expect(find.text('Account Connected & Active'), findsOneWidget);
      expect(find.text('Sync Routines Now'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);

      await db.close();
    });
  });
}
