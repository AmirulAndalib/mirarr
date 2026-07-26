import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Material 3 Expressive Loading Spinner
/// Features dynamic morphing dual-arcs, gradient sweeps, and breathing scale pulses.
class M3ExpressiveSpinner extends StatefulWidget {
  final double size;
  final Color? color;
  final Color? secondaryColor;

  const M3ExpressiveSpinner({
    super.key,
    this.size = 48.0,
    this.color,
    this.secondaryColor,
  });

  @override
  State<M3ExpressiveSpinner> createState() => _M3ExpressiveSpinnerState();
}

class _M3ExpressiveSpinnerState extends State<M3ExpressiveSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? theme.colorScheme.primary;
    final secondaryColor = widget.secondaryColor ?? theme.colorScheme.tertiary;
    final trackColor = theme.colorScheme.surfaceContainerHigh;

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;
          final scale = 0.92 + (0.08 * math.sin(value * 2 * math.pi));

          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size + 16,
              height: widget.size + 16,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: trackColor.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _M3ExpressiveSpinnerPainter(
                    progress: value,
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    trackColor: primaryColor.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _M3ExpressiveSpinnerPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final Color trackColor;

  _M3ExpressiveSpinnerPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 4;
    const strokeWidth = 4.0;

    // 1. Draw Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Main Morphing Primary Arc
    final rotationAngle = progress * 2 * math.pi;
    final startAngle = rotationAngle;
    final sweepAngle = (math.pi * 0.8) + (math.pi * 0.4 * math.sin(progress * 2 * math.pi));

    final primaryPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          primaryColor.withValues(alpha: 0.2),
          primaryColor,
          secondaryColor,
        ],
        stops: const [0.0, 0.6, 1.0],
        transform: GradientRotation(rotationAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      primaryPaint,
    );

    // 3. Counter-rotating Secondary Accent Dot
    final dotAngle = -rotationAngle * 1.5;
    final dotRadius = radius - 7;
    final dotOffset = Offset(
      center.dx + dotRadius * math.cos(dotAngle),
      center.dy + dotRadius * math.sin(dotAngle),
    );

    final dotPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dotOffset, 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _M3ExpressiveSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
