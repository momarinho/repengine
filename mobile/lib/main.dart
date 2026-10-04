import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/workout_execution/presentation/workout_execution_screen.dart';

void main() {
  runApp(const ProviderScope(child: RepEngineApp()));
}

class RepEngineApp extends StatelessWidget {
  const RepEngineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepEngine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const WorkoutExecutionScreen(),
    );
  }
}
