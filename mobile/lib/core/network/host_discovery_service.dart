import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Service that automatically detects the RepEngine Mobile BFF host on the local network (LAN / Wi-Fi).
class HostDiscoveryService {
  final http.Client _client;

  HostDiscoveryService({http.Client? client}) : _client = client ?? http.Client();

  /// Probes well-known and local subnet addresses to discover the RepEngine Mobile BFF host.
  ///
  /// Returns the full host URL (e.g. 'http://192.168.100.2:8081') if found, or null otherwise.
  Future<String?> discoverBffHost({
    Duration timeoutPerProbe = const Duration(milliseconds: 600),
    Duration overallTimeout = const Duration(seconds: 4),
    int targetPort = 8081,
  }) async {
    if (kIsWeb) {
      final webHost = 'http://localhost:$targetPort';
      if (await _verifyBff(webHost)) return webHost;
      return null;
    }

    try {
      return await _runDiscovery(
        timeoutPerProbe: timeoutPerProbe,
        targetPort: targetPort,
      ).timeout(overallTimeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _runDiscovery({
    required Duration timeoutPerProbe,
    required int targetPort,
  }) async {
    // 1. Fast check for well-known loopback / emulator / LAN hosts
    final quickCandidates = [
      'http://192.168.100.2:$targetPort',
      'http://localhost:$targetPort',
      'http://10.0.2.2:$targetPort',
    ];

    for (final candidate in quickCandidates) {
      if (await _verifyBff(candidate, timeout: const Duration(milliseconds: 400))) {
        return candidate;
      }
    }

    // 2. Discover local Wi-Fi / Ethernet subnets from network interfaces
    final subnets = await _getLocalSubnets();
    for (final subnet in subnets) {
      final found = await _scanSubnet(subnet, targetPort, timeoutPerProbe);
      if (found != null) {
        return found;
      }
    }

    return null;
  }

  /// Extracts active local IPv4 subnet prefixes (e.g. '192.168.1' from '192.168.1.50').
  Future<Set<String>> _getLocalSubnets() async {
    final subnets = <String>{'192.168.100', '192.168.1', '192.168.0'};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          // Filter out loopback, link-local, and docker bridge networks
          if (ip.startsWith('127.') ||
              ip.startsWith('169.254.') ||
              ip.startsWith('172.17.') ||
              ip.startsWith('172.18.')) {
            continue;
          }

          final parts = ip.split('.');
          if (parts.length == 4) {
            subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
          }
        }
      }
    } catch (_) {}
    return subnets;
  }

  /// Scans candidates in a /24 subnet in parallel batches to find port [targetPort].
  Future<String?> _scanSubnet(
    String subnet,
    int targetPort,
    Duration timeout,
  ) async {
    // Generate all 254 possible host addresses in the subnet
    final candidates = List.generate(254, (i) => '$subnet.${i + 1}');
    const batchSize = 50;

    for (var i = 0; i < candidates.length; i += batchSize) {
      final end = (i + batchSize < candidates.length) ? i + batchSize : candidates.length;
      final batch = candidates.sublist(i, end);

      final completer = Completer<String?>();
      var remaining = batch.length;

      for (final ip in batch) {
        Socket.connect(ip, targetPort, timeout: timeout).then((socket) async {
          socket.destroy();
          final hostUrl = 'http://$ip:$targetPort';
          final isValid = await _verifyBff(hostUrl, timeout: const Duration(milliseconds: 1000));
          if (isValid && !completer.isCompleted) {
            completer.complete(hostUrl);
          } else {
            remaining--;
            if (remaining == 0 && !completer.isCompleted) {
              completer.complete(null);
            }
          }
        }).catchError((_) {
          remaining--;
          if (remaining == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        });
      }

      final foundInBatch = await completer.future;
      if (foundInBatch != null) {
        return foundInBatch;
      }
    }

    return null;
  }

  /// Validates that a host is running the RepEngine Mobile BFF by inspecting the /api/v1/health response.
  Future<bool> _verifyBff(
    String host, {
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    try {
      final uri = Uri.parse('$host/api/v1/health');
      final res = await _client.get(uri).timeout(timeout);
      if (res.statusCode == 200) {
        final body = res.body;
        if (body.contains('repengine_mobile_bff')) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }
}

/// Riverpod provider for HostDiscoveryService.
final hostDiscoveryServiceProvider = Provider<HostDiscoveryService>((ref) {
  return HostDiscoveryService();
});
