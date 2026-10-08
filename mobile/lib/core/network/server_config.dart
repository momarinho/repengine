import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'host_discovery_service.dart';

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
  final Ref? _ref;

  bool _simulateOffline = false;
  bool get simulateOffline => _simulateOffline;

  ServerConfigNotifier([this._ref]) : super(_defaultHost()) {
    _loadFromPrefs();
  }

  static String _defaultHost() {
    if (kIsWeb) return 'http://localhost:8081';
    try {
      if (Platform.isAndroid) {
        // On Android emulator, 10.0.2.2 maps to host PC localhost
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

  /// Automatically scans local LAN / Wi-Fi to locate the RepEngine Mobile BFF host.
  Future<String?> autoDiscover({bool save = true}) async {
    final discoveryService = _ref?.read(hostDiscoveryServiceProvider) ?? HostDiscoveryService();
    final discovered = await discoveryService.discoverBffHost();
    if (discovered != null && save) {
      await setHost(discovered);
    }
    return discovered;
  }

  Future<void> setSimulateOffline(bool offline) async {
    _simulateOffline = offline;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_simulateOfflineKey, offline);
  }
}

final serverHostProvider = StateNotifierProvider<ServerConfigNotifier, String>((ref) {
  return ServerConfigNotifier(ref);
});

class ServerHealthNotifier extends StateNotifier<ServerConnectionState> {
  final Ref _ref;
  Timer? _heartbeatTimer;
  bool _hasAttemptedAutoDiscovery = false;

  ServerHealthNotifier(this._ref, {bool autoStartTimer = true})
      : super(
          ServerConnectionState(
            state: ConnectionStateEnum.checking,
            lastCheckedAt: DateTime.now(),
          ),
        ) {
    if (autoStartTimer) {
      checkHealth(allowAutoDiscover: true);
      // Automatic heartbeat every 15 seconds
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

  void resetAutoDiscoveryAttempt() {
    _hasAttemptedAutoDiscovery = false;
  }

  Future<ServerConnectionState> checkHealth({bool allowAutoDiscover = false}) async {
    final notifier = _ref.read(serverHostProvider.notifier);
    if (notifier.simulateOffline) {
      state = ServerConnectionState(
        state: ConnectionStateEnum.offline,
        errorMessage: 'Forced Gym Mode (offline simulation active)',
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

      // Fallback to root route
      final rootRes = await http.get(Uri.parse(host)).timeout(const Duration(milliseconds: 2000));
      if (rootRes.statusCode == 200) {
        state = ServerConnectionState(
          state: ConnectionStateEnum.online,
          latencyMs: stopwatch.elapsedMilliseconds,
          lastCheckedAt: DateTime.now(),
        );
        return state;
      }

      // If initial check failed, trigger auto-discovery on startup / on-demand if not attempted yet
      if (allowAutoDiscover && !_hasAttemptedAutoDiscovery) {
        _hasAttemptedAutoDiscovery = true;
        final discovered = await notifier.autoDiscover();
        if (discovered != null && discovered != host) {
          return await checkHealth(allowAutoDiscover: false);
        }
      }

      state = ServerConnectionState(
        state: ConnectionStateEnum.offline,
        errorMessage: 'HTTP status ${res.statusCode}',
        lastCheckedAt: DateTime.now(),
      );
      return state;
    } catch (e) {
      stopwatch.stop();

      // If network failed, trigger auto-discovery on startup / on-demand if not attempted yet
      if (allowAutoDiscover && !_hasAttemptedAutoDiscovery) {
        _hasAttemptedAutoDiscovery = true;
        final discovered = await notifier.autoDiscover();
        if (discovered != null && discovered != host) {
          return await checkHealth(allowAutoDiscover: false);
        }
      }

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
