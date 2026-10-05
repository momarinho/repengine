import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionStateEnum {
  online,
  offline,
  checking,
}

@immutable
class ServerConnectionState {
  final ConnectionStateEnum state;
  final int? latencyMs;
  final String? errorMessage;
  final DateTime lastCheckedAt;

  const ServerConnectionState({
    required this.state,
    this.latencyMs,
    this.errorMessage,
    required this.lastCheckedAt,
  });

  bool get isOnline => state == ConnectionStateEnum.online;
}

class ServerConfigNotifier extends StateNotifier<String> {
  static const _hostKey = 'repengine_server_host';
  static const _simulateOfflineKey = 'repengine_simulate_offline';

  bool _simulateOffline = false;
  bool get simulateOffline => _simulateOffline;

  ServerConfigNotifier() : super(_defaultHost()) {
    _loadFromPrefs();
  }

  static String _defaultHost() {
    if (kIsWeb) return 'http://localhost:8081';
    try {
      if (Platform.isAndroid) {
        // No emulador Android, 10.0.2.2 mapeia para o localhost do host PC
        return 'http://10.0.2.2:8081';
      }
    } catch (_) {}
    return 'http://localhost:8081';
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHost = prefs.getString(_hostKey);
    final savedOffline = prefs.getBool(_simulateOfflineKey) ?? false;
    _simulateOffline = savedOffline;

    if (savedHost != null && savedHost.trim().isNotEmpty) {
      state = savedHost.trim();
    }
  }

  Future<void> setHost(String newHost) async {
    final cleaned = newHost.trim().replaceAll(RegExp(r'/+$'), '');
    state = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, cleaned);
  }

  Future<void> setSimulateOffline(bool offline) async {
    _simulateOffline = offline;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_simulateOfflineKey, offline);
  }
}

final serverHostProvider = StateNotifierProvider<ServerConfigNotifier, String>((ref) {
  return ServerConfigNotifier();
});

class ServerHealthNotifier extends StateNotifier<ServerConnectionState> {
  final Ref _ref;
  Timer? _heartbeatTimer;

  ServerHealthNotifier(this._ref, {bool autoStartTimer = true})
      : super(
          ServerConnectionState(
            state: ConnectionStateEnum.checking,
            lastCheckedAt: DateTime.now(),
          ),
        ) {
    if (autoStartTimer) {
      checkHealth();
      // Heartbeat automático a cada 15 segundos
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        checkHealth();
      });
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<ServerConnectionState> checkHealth() async {
    final notifier = _ref.read(serverHostProvider.notifier);
    if (notifier.simulateOffline) {
      state = ServerConnectionState(
        state: ConnectionStateEnum.offline,
        errorMessage: 'Modo Academia forçado (simulação offline ativa)',
        lastCheckedAt: DateTime.now(),
      );
      return state;
    }

    final host = _ref.read(serverHostProvider);
    state = ServerConnectionState(
      state: ConnectionStateEnum.checking,
      lastCheckedAt: DateTime.now(),
    );

    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('$host/api/v1/health');
      final res = await http.get(uri).timeout(const Duration(milliseconds: 2500));
      stopwatch.stop();

      if (res.statusCode == 200) {
        state = ServerConnectionState(
          state: ConnectionStateEnum.online,
          latencyMs: stopwatch.elapsedMilliseconds,
          lastCheckedAt: DateTime.now(),
        );
        return state;
      }

      // Fallback para rota raiz
      final rootRes = await http.get(Uri.parse(host)).timeout(const Duration(milliseconds: 2000));
      if (rootRes.statusCode == 200) {
        state = ServerConnectionState(
          state: ConnectionStateEnum.online,
          latencyMs: stopwatch.elapsedMilliseconds,
          lastCheckedAt: DateTime.now(),
        );
        return state;
      }

      state = ServerConnectionState(
        state: ConnectionStateEnum.offline,
        errorMessage: 'Código HTTP ${res.statusCode}',
        lastCheckedAt: DateTime.now(),
      );
      return state;
    } catch (e) {
      stopwatch.stop();
      state = ServerConnectionState(
        state: ConnectionStateEnum.offline,
        errorMessage: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
        lastCheckedAt: DateTime.now(),
      );
      return state;
    }
  }
}

final serverHealthProvider = StateNotifierProvider<ServerHealthNotifier, ServerConnectionState>((ref) {
  return ServerHealthNotifier(ref);
});
