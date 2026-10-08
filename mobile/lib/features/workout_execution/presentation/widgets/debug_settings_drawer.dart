import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/server_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../controller/workout_execution_controller.dart';

class DebugSettingsDrawer extends ConsumerStatefulWidget {
  const DebugSettingsDrawer({super.key});

  @override
  ConsumerState<DebugSettingsDrawer> createState() => _DebugSettingsDrawerState();
}

class _DebugSettingsDrawerState extends ConsumerState<DebugSettingsDrawer> {
  late final TextEditingController _hostController;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final currentHost = ref.read(serverHostProvider);
    _hostController = TextEditingController(text: currentHost);
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    HapticFeedback.lightImpact();
    await ref.read(serverHostProvider.notifier).setHost(_hostController.text);
    await ref.read(serverHealthProvider.notifier).checkHealth();
    if (mounted) {
      setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(serverHealthProvider);
    final currentHost = ref.watch(serverHostProvider);
    final hostNotifier = ref.watch(serverHostProvider.notifier);
    final syncQueueAsync = ref.watch(syncQueueStreamProvider);

    return Drawer(
      backgroundColor: AppColors.surface,
      width: MediaQuery.of(context).size.width * 0.88,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hub_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Diagnostics & Network', style: AppTypography.titleMedium),
                        Text(
                          'Local Sync (PC ↔ Mobile)',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.outlineVariant, height: 1),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. CONNECTION STATUS CARD
                  _buildConnectionStatusCard(health),
                  const SizedBox(height: 16),

                  // 2. HOST CONFIGURATION
                  _buildHostConfigCard(currentHost),
                  const SizedBox(height: 16),

                  // 3. GYM MODE (OFFLINE SIMULATION)
                  _buildOfflineSimulationCard(hostNotifier),
                  const SizedBox(height: 20),

                  // 4. DRIFT QUEUE INSPECTOR (SyncQueueTable)
                  _buildSyncQueueInspector(syncQueueAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard(ServerConnectionState health) {
    final (Color badgeBg, Color badgeColor, IconData icon, String title) = switch (health.state) {
      ConnectionStateEnum.online => (
          const Color(0x2298BB6C),
          AppColors.success,
          Icons.check_circle_rounded,
          'Docker Active on PC',
        ),
      ConnectionStateEnum.offline => (
          const Color(0x22EB6F92),
          AppColors.primary,
          Icons.wifi_off_rounded,
          'PC Offline / Disconnected',
        ),
      ConnectionStateEnum.checking => (
          const Color(0x227AA89F),
          AppColors.secondary,
          Icons.sync_rounded,
          'Checking connection...',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                child: Icon(icon, color: badgeColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.titleMedium.copyWith(color: badgeColor)),
                    if (health.latencyMs != null)
                      Text(
                        'Latency: ${health.latencyMs} ms',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(_isTesting ? 'Ping...' : 'Ping'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  backgroundColor: AppColors.surfaceContainerLowest,
                  foregroundColor: AppColors.onSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: AppTypography.labelSmall,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
              ),
            ],
          ),
          if (health.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                health.errorMessage!,
                style: AppTypography.labelSmall.copyWith(color: AppColors.primaryContainer),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHostConfigCard(String currentHost) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PC Address (BFF Host)', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _hostController,
            style: AppTypography.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
              hintText: 'http://192.168.x.x:8081',
              hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.outlineVariant),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.save, size: 20, color: AppColors.primary),
                tooltip: 'Save Host',
                onPressed: () async {
                  await ref.read(serverHostProvider.notifier).setHost(_hostController.text);
                  await ref.read(serverHealthProvider.notifier).checkHealth();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Host saved successfully!')),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Quick presets:', style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _presetChip('Desktop (localhost)', 'http://localhost:8081'),
              _presetChip('Emulator (10.0.2.2)', 'http://10.0.2.2:8081'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, String host) {
    return ActionChip(
      label: Text(label),
      labelStyle: AppTypography.labelSmall.copyWith(color: AppColors.onSurface),
      backgroundColor: AppColors.surfaceContainerHigh,
      side: const BorderSide(color: AppColors.outlineVariant),
      onPressed: () {
        _hostController.text = host;
        ref.read(serverHostProvider.notifier).setHost(host);
        _testConnection();
      },
    );
  }

  Widget _buildOfflineSimulationCard(ServerConfigNotifier notifier) {
    return Material(
      color: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text('Simulate Gym / Offline Mode', style: AppTypography.labelMedium),
        subtitle: Text(
          'Forces offline mode to test local outbox queue and autonomy.',
          style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant),
        ),
        value: notifier.simulateOffline,
        activeThumbColor: AppColors.primary,
        onChanged: (val) async {
          await notifier.setSimulateOffline(val);
          await ref.read(serverHealthProvider.notifier).checkHealth();
          setState(() {});
        },
      ),
    );
  }

  Widget _buildSyncQueueInspector(AsyncValue<List<dynamic>> queueAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('SQLite Queue (SyncQueueTable)', style: AppTypography.labelMedium),
            queueAsync.maybeWhen(
              data: (items) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: items.isEmpty ? AppColors.surfaceContainerHigh : AppColors.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${items.length} pending',
                  style: AppTypography.labelSmall.copyWith(
                    color: items.isEmpty ? AppColors.onSurfaceVariant : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        queueAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_done_outlined, size: 28, color: AppColors.success),
                      const SizedBox(height: 6),
                      Text(
                        'Queue empty!',
                        style: AppTypography.titleMedium.copyWith(color: AppColors.success),
                      ),
                      Text(
                        'No sets or sessions waiting to be pushed.',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                Map<String, dynamic> payloadMap = {};
                try {
                  payloadMap = jsonDecode(item.payload as String);
                } catch (_) {}

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.entityType == 'set_log'
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.action} • ${item.entityType.toUpperCase()}',
                              style: AppTypography.labelSmall.copyWith(
                                color: item.entityType == 'set_log' ? AppColors.primary : AppColors.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.status.toUpperCase(),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ID: ${item.entityClientId}',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
                      ),
                      if (payloadMap.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            payloadMap.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 9,
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error reading queue: $err'),
        ),
      ],
    );
  }
}
