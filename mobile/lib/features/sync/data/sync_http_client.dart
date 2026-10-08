import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:repengine_core/repengine_core.dart';

import '../../../../core/network/server_config.dart';
import '../../auth/data/auth_repository.dart';

/// HTTP client for synchronization between Flutter Mobile and Dart Frog BFF.
///
/// Responsible for:
/// 1. Pulling workflows and routines created on Desktop Web (Pull).
/// 2. Pushing completed sessions and sets logged at the gym (Push).
class SyncHttpClient {
  final http.Client _client;
  final String _baseUrl;
  final String _authToken;

  SyncHttpClient({
    http.Client? client,
    required String baseUrl,
    this._authToken = 'dev-token',
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

  /// Fetches updated and deleted workflows since [lastSyncedAt].
  ///
  /// On connection failure or timeout, returns `null` gracefully
  /// without throwing exceptions to the presentation layer.
  Future<SyncPullResponse?> pullWorkflows({DateTime? lastSyncedAt}) async {
    final queryParams = <String, String>{};
    if (lastSyncedAt != null) {
      queryParams['last_synced_at'] = lastSyncedAt.toUtc().toIso8601String();
    }

    final uri = Uri.parse('$_baseUrl/api/v1/mobile/sync/pull').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == HttpStatus.ok) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        return SyncPullResponse.fromJson(jsonMap);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Dispatches an offline batch of completed sessions and set logs to the server.
  ///
  /// Returns [SyncPushResult] containing per-item receipt status (`accepted`, `ignoredDuplicate`).
  Future<SyncPushResult?> pushMutations(SyncPushPayload payload) async {
    if (payload.sessions.isEmpty && payload.setLogs.isEmpty) {
      return null;
    }

    final uri = Uri.parse('$_baseUrl/api/v1/mobile/sync/push');

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload.toJson()),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == HttpStatus.ok) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        return SyncPushResult.fromJson(jsonMap);
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Global provider for SyncHttpClient watching dynamic server host and athlete JWT token
final syncHttpClientProvider = Provider<SyncHttpClient>((ref) {
  final host = ref.watch(serverHostProvider);
  final authState = ref.watch(authStateProvider);
  final token = authState.token ?? 'dev-token';
  return SyncHttpClient(
    baseUrl: host,
    authToken: token,
  );
});
