import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Circular timer ring with progress indicator.
///
/// Design from Penpot:
/// - Ring size: 200x200
/// - Stroke width: 8
/// - Background stroke: inputBackground (#262626)
/// - Active stroke: varies by state (work/rest/warning)
class CircularTimerRing extends StatefulWidget {
  final double progress;
  final String time;
  final Color? progressColor;
  final Color? backgroundColor;
  final double strokeWidth;
  final double size;
  final Widget? centerWidget;

  const CircularTimerRing({
    super.key,
    required this.progress,
    required this.time,
    this.progressColor,
    this.backgroundColor,
    this.strokeWidth = 8,
    this.size = 200,
    this.centerWidget,
  });

  @override
  State<CircularTimerRing> createState() => _CircularTimerRingState();
}

class _CircularTimerRingState extends State<CircularTimerRing> {
  double _previousProgress = 0;

  @override
  void didUpdateWidget(CircularTimerRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousProgress = oldWidget.progress;
  }

  // Smooth animation over 1 second to match timer ticks, instant reset
  Duration get _animationDuration {
    // Instant reset only when progress jumps to 0 or near 0
    if (widget.progress < 0.05 && _previousProgress > 0.5) {
      return const Duration(milliseconds: 50);
    }
    // Animate over full second for smooth continuous progress (forward or backward)
    return const Duration(milliseconds: 1000);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background dots (unprogressed part)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: _previousProgress, end: widget.progress),
            duration: _animationDuration,
            curve: Curves.linear,
            builder: (context, animatedProgress, _) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _TimerRingPainter(
                  progress: animatedProgress,
                  color: widget.backgroundColor ?? AppColors.textMuted,
                  strokeWidth: widget.strokeWidth,
                  drawDots: true,
                ),
              );
            },
          ),

          // Progress ring (solid arc)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: _previousProgress, end: widget.progress),
            duration: _animationDuration,
            curve: Curves.linear,
            builder: (context, animatedProgress, _) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _TimerRingPainter(
                  progress: animatedProgress,
                  color: widget.progressColor ?? AppColors.primary,
                  strokeWidth: widget.strokeWidth,
                  hasGlow: true,
                  drawDots: false,
                ),
              );
            },
          ),

          // Center content
          widget.centerWidget ??
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.time,
                    style: AppTextStyles.timerLarge.copyWith(
                      fontSize: widget.size * 0.22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool hasGlow;
  final bool drawDots; // If true, draws dots; if false, draws arc

  _TimerRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    this.hasGlow = false,
    this.drawDots = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    if (drawDots) {
      // Draw dots for unprogressed part
      _drawDots(canvas, center, radius);
    } else {
      // Draw solid arc for progress
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Add glow effect for progress ring
      if (hasGlow && progress > 0) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          2 * math.pi * progress,
          false,
          glowPaint,
        );
      }

      // Draw the arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        paint,
      );
    }
  }

  void _drawDots(Canvas canvas, Offset center, double radius) {
    final dotRadius = strokeWidth / 4;
    final circumference = 2 * math.pi * radius;
    final dotSpacing = dotRadius * 5; // Space between dot centers
    final numDots = (circumference / dotSpacing).floor();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < numDots; i++) {
      final dotProgress = i / numDots;

      // Only draw dots for the unprogressed part (after progress point)
      if (dotProgress < progress) continue;

      final angle = -math.pi / 2 + (2 * math.pi * dotProgress);
      final dotCenter = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      canvas.drawCircle(dotCenter, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.drawDots != drawDots;
  }
}

/// Animated timer ring with pulse effect on countdown.
///
/// Design from Penpot:
/// - Default size: 200
/// - Shows label above time (e.g., "Round 3 - Work")
/// - Shows sublabel below time (e.g., "15:30 remaining")
class AnimatedTimerRing extends StatefulWidget {
  final double progress;
  final String time;
  final Color? progressColor;
  final double size;
  final Widget? centerWidget;
  final String? label;
  final String? subLabel;

  const AnimatedTimerRing({
    super.key,
    required this.progress,
    required this.time,
    this.progressColor,
    this.size = 200,
    this.centerWidget,
    this.label,
    this.subLabel,
  });

  @override
  State<AnimatedTimerRing> createState() => _AnimatedTimerRingState();
}

class _AnimatedTimerRingState extends State<AnimatedTimerRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(AnimatedTimerRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pulse animation disabled
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: CircularTimerRing(
            progress: widget.progress,
            time: widget.time,
            progressColor: widget.progressColor,
            size: widget.size,
            centerWidget: widget.centerWidget ??
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.label != null)
                      Text(
                        widget.label!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 2,
                        ),
                      ),
                    Text(
                      widget.time,
                      style: AppTextStyles.timerLarge.copyWith(
                        fontSize: widget.size * 0.22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.subLabel != null)
                      Text(
                        widget.subLabel!,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
          ),
        );
      },
    );
  }
}
