import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/server_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../sync/application/sync_engine.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

class AthleteAuthScreen extends ConsumerStatefulWidget {
  const AthleteAuthScreen({super.key});

  @override
  ConsumerState<AthleteAuthScreen> createState() => _AthleteAuthScreenState();
}

class _AthleteAuthScreenState extends ConsumerState<AthleteAuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController();
  bool _obscurePassword = true;
  bool _showAdvancedServer = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _serverController.text = ref.read(serverHostProvider);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await ref.read(authStateProvider.notifier).login(
          email: email,
          password: password,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged in successfully as $email'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Log Out', style: AppTypography.titleMedium),
        content: const Text(
          'Are you sure you want to log out? Local synced routines from this account will be cleared until you log in again.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authStateProvider.notifier).logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Switched to Guest / Offline mode'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    }
  }

  Future<void> _handleManualSync() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(syncEngineProvider.notifier).syncNow(forceFullSync: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud sync completed!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isAuthenticating = authState.status == AuthStatus.authenticating;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          authState.isAuthenticated ? 'Athlete Profile' : 'Account & Sync',
          style: AppTypography.titleMedium,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: authState.isAuthenticated
              ? _buildAuthenticatedProfile(authState)
              : _buildLoginForm(authState, isAuthenticating),
        ),
      ),
    );
  }

  Widget _buildAuthenticatedProfile(AuthState authState) {
    final currentHost = ref.watch(serverHostProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Profile Avatar & Email Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.person, size: 36, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                authState.email ?? 'Athlete',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'RepEngine ID: #${authState.userId ?? 0}',
                style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x2298BB6C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: AppColors.success),
                    SizedBox(width: 6),
                    Text(
                      'Account Connected & Active',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Cloud Sync Actions Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CLOUD SYNC', style: AppTypography.labelSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.dns_rounded, size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Host: $currentHost',
                      style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: _isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync Routines Now'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: _isSyncing ? null : _handleManualSync,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Log out button
        OutlinedButton.icon(
          icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
          label: const Text('Log Out', style: TextStyle(color: AppColors.error)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.error),
            minimumSize: const Size.fromHeight(46),
          ),
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildLoginForm(AuthState authState, bool isAuthenticating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: const Center(
                  child: Icon(Icons.bolt, size: 34, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'RepEngine Athlete',
                style: AppTypography.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in with your Web credentials to sync your training routines and history across all your devices.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Error Banner
        if (authState.status == AuthStatus.error && authState.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x22E82424),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    authState.errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Input Fields
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: const OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 20),

        // Sign In Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: isAuthenticating ? null : _handleLogin,
          child: isAuthenticating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                )
              : const Text('Log In & Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),

        const SizedBox(height: 12),

        // Guest Mode Button
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Train Offline / Guest Mode'),
        ),

        const SizedBox(height: 16),

        // Advanced Server Options Toggle
        Center(
          child: TextButton.icon(
            icon: Icon(
              _showAdvancedServer ? Icons.expand_less : Icons.tune_rounded,
              size: 16,
              color: AppColors.onSurfaceVariant,
            ),
            label: Text(
              _showAdvancedServer ? 'Hide Server Settings' : 'Server Connection Settings',
              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            onPressed: () => setState(() => _showAdvancedServer = !_showAdvancedServer),
          ),
        ),

        if (_showAdvancedServer) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('SERVER ENDPOINT (BFF)', style: AppTypography.labelSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _serverController,
                  decoration: const InputDecoration(
                    hintText: 'http://192.168.x.x:8081',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerHighest,
                    foregroundColor: AppColors.onBackground,
                  ),
                  onPressed: () async {
                    final newHost = _serverController.text.trim();
                    if (newHost.isNotEmpty) {
                      await ref.read(serverHostProvider.notifier).setHost(newHost);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Host updated to $newHost')),
                        );
                      }
                    }
                  },
                  child: const Text('Update Host'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
