import 'package:flutter/material.dart';
import '../../providers/video_provider.dart';

/// Draggable timer overlay for video recording - minimalistic style (no background)
class TimerOverlay extends StatelessWidget {
  final String time;
  final double progress;
  final OverlayStyle style;
  final double size;
  final Color? progressColor;
  final String? roundIndicator;
  final bool isRest;
  final bool isDragging;
  final VoidCallback? onDragStart;
  final void Function(DragUpdateDetails)? onDragUpdate;
  final VoidCallback? onDragEnd;

  const TimerOverlay({
    super.key,
    required this.time,
    required this.progress,
    this.style = OverlayStyle.minimal,
    this.size = 120,
    this.progressColor,
    this.roundIndicator,
    this.isRest = false,
    this.isDragging = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => onDragStart?.call(),
      onPanUpdate: onDragUpdate,
      onPanEnd: (_) => onDragEnd?.call(),
      child: _MinimalOverlay(
        time: time,
        roundIndicator: roundIndicator,
        isRest: isRest,
        isDragging: isDragging,
      ),
    );
  }
}

/// Minimal overlay - just time text with round/rest indicator below (no background)
class _MinimalOverlay extends StatelessWidget {
  final String time;
  final String? roundIndicator;
  final bool isRest;
  final bool isDragging;

  const _MinimalOverlay({
    required this.time,
    this.roundIndicator,
    this.isRest = false,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Round/Rest indicator (above timer)
        if (roundIndicator != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              isRest ? 'Rest $roundIndicator' : 'Round $roundIndicator',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),
        // Time display
        Text(
          time,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
