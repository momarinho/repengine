import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/server_config.dart';
import '../../sync/application/sync_engine.dart';
import '../../workout_execution/controller/workout_execution_controller.dart';
import '../../workout_execution/data/workout_repository.dart';
import '../domain/auth_state.dart';

/// Athlete authentication state manager, connecting to the Web account
/// through the BFF and persisting the session in local storage.
class AuthNotifier extends StateNotifier<AuthState> {
  static const _tokenKey = 'repengine_auth_token';
  static const _userIdKey = 'repengine_auth_user_id';
  static const _emailKey = 'repengine_auth_email';

  final Ref ref;
  final http.Client _client;
  SharedPreferences? prefs;

  AuthNotifier(
    this.ref, {
    http.Client? client,
    this.prefs,
  })  : _client = client ?? http.Client(),
        super(const AuthState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    prefs ??= await SharedPreferences.getInstance();
    final token = prefs?.getString(_tokenKey);
    final userId = prefs?.getInt(_userIdKey);
    final email = prefs?.getString(_emailKey);

    if (token != null && token.isNotEmpty && userId != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
        userId: userId,
        email: email,
      );
    }
  }

  /// Authenticates the athlete using credentials registered on RepEngine Web.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter your email and password.',
      );
      return false;
    }

    state = state.copyWith(
      status: AuthStatus.authenticating,
      errorMessage: null,
    );

    final baseUrl =
        ref.read(serverHostProvider).replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseUrl/api/v1/mobile/auth/login');

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': cleanEmail,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = data['token']?.toString() ?? '';
        final userId = data['user_id'] as int? ?? 0;

        prefs ??= await SharedPreferences.getInstance();
        await prefs?.setString(_tokenKey, token);
        await prefs?.setInt(_userIdKey, userId);
        await prefs?.setString(_emailKey, cleanEmail);

        // Clear previous sync cache and reset routine selection
        await ref.read(syncEngineProvider.notifier).clearSyncCache();
        ref.read(selectedRoutineIdProvider.notifier).state = null;
        ref.read(selectedSectionIdProvider.notifier).state = null;

        state = AuthState(
          status: AuthStatus.authenticated,
          token: token,
          userId: userId,
          email: cleanEmail,
        );

        // Trigger immediate full sync to download routines and blocks from Web
        await ref.read(syncEngineProvider.notifier).syncNow(forceFullSync: true);

        return true;
      } else {
        final msg = data['error'] ??
            data['message'] ??
            'Invalid credentials. Please verify your login.';
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: msg.toString(),
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Could not connect to server ($e).',
      );
      return false;
    }
  }

  /// Ends connected session and returns to guest / local offline mode.
  Future<void> logout() async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs?.remove(_tokenKey);
    await prefs?.remove(_userIdKey);
    await prefs?.remove(_emailKey);

    await ref.read(syncEngineProvider.notifier).clearSyncCache();
    await ref.read(workoutRepositoryProvider).clearRoutines();
    ref.read(selectedRoutineIdProvider.notifier).state = null;
    ref.read(selectedSectionIdProvider.notifier).state = null;

    state = const AuthState(status: AuthStatus.guest);
  }
}

/// Global provider for athlete authentication
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
