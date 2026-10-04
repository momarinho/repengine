import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Cronômetro circular de descanso desenhado em Canvas nativo a 120 FPS.
class CircularRestTimerWidget extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback onFinished;
  final VoidCallback onDismissed;

  const CircularRestTimerWidget({
    super.key,
    required this.totalSeconds,
    required this.onFinished,
    required this.onDismissed,
  });

  @override
  State<CircularRestTimerWidget> createState() => _CircularRestTimerWidgetState();
}

class _CircularRestTimerWidgetState extends State<CircularRestTimerWidget>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  late int _initialSeconds;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _initialSeconds = widget.totalSeconds;
    _remainingSeconds = widget.totalSeconds;
    _startTimer();
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        HapticFeedback.heavyImpact();
        widget.onFinished();
      } else {
        setState(() {
          _remainingSeconds--;
        });
        // Feedback tátil nos últimos 3 segundos (3, 2, 1)
        if (_remainingSeconds <= 3) {
          HapticFeedback.lightImpact();
        }
      }
    });
  }

  void _addSeconds(int seconds) {
    setState(() {
      _remainingSeconds += seconds;
      if (_remainingSeconds > _initialSeconds) {
        _initialSeconds = _remainingSeconds;
      }
    });
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _initialSeconds > 0
        ? _remainingSeconds / _initialSeconds
        : 0.0;

    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeString =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TEMPO DE DESCANSO', style: AppTypography.labelLarge),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                onPressed: widget.onDismissed,
                tooltip: 'Pular Descanso',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Canvas circular nativo
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _RestTimerPainter(progress: progress),
              child: Center(
                child: Text(
                  timeString,
                  style: AppTypography.displayLarge.copyWith(fontSize: 32),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Ações rápidas (+30s / Pular)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _addSeconds(30),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+30s'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onBackground,
                  side: const BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: widget.onDismissed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerHighest,
                  foregroundColor: AppColors.onBackground,
                ),
                child: const Text('Pular'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestTimerPainter extends CustomPainter {
  final double progress;

  _RestTimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Anel de fundo
    final bgPaint = Paint()
      ..color = AppColors.surfaceContainerLowest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, bgPaint);

    // Anel de progresso
    final progressPaint = Paint()
      ..color = progress > 0.25 ? AppColors.primary : AppColors.error
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RestTimerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
