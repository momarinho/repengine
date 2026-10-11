import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/athlete_auth_screen.dart';
import 'features/workout_execution/presentation/workout_execution_screen.dart';

void main() {
  runApp(const ProviderScope(child: RepEngineApp()));
}

class RepEngineApp extends ConsumerWidget {
  const RepEngineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initAsync = ref.watch(authInitializedProvider);

    return MaterialApp(
      title: 'RepEngine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: initAsync.when(
        data: (_) {
          final authState = ref.watch(authStateProvider);
          final isGuest = ref.watch(guestModeActiveProvider);
          if (authState.isAuthenticated || isGuest) {
            return const WorkoutExecutionScreen();
          }
          return const AthleteAuthScreen();
        },
        loading: () => const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (_, _) => const AthleteAuthScreen(),
      ),
    );
  }
}
