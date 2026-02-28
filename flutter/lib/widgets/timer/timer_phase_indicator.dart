import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Segmented indicator showing current phase (ROUND/REST, WORK/REST, etc.)
/// Reusable across different timer types
class TimerPhaseIndicator extends StatelessWidget {
  final List<PhaseSegment> segments;
  final int activeIndex;
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final double borderRadius;

  const TimerPhaseIndicator({
    super.key,
    required this.segments,
    this.activeIndex = 0,
    this.activeColor = AppColors.primary,
    this.inactiveColor = AppColors.textPrimary,
    this.height = 48,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments.asMap().entries.map((entry) {
          final index = entry.key;
          final segment = entry.value;
          final isActive = index == activeIndex;

          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 4 : 0,
              right: index == segments.length - 1 ? 4 : 0,
            ),
            child: _SegmentItem(
              segment: segment,
              isActive: isActive,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              isFirst: index == 0,
              isLast: index == segments.length - 1,
              borderRadius: borderRadius,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final PhaseSegment segment;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final bool isFirst;
  final bool isLast;
  final double borderRadius;

  const _SegmentItem({
    required this.segment,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.isFirst,
    required this.isLast,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.surfaceBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius - 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            segment.label,
            style: AppTextStyles.buttonSmall.copyWith(
              color: isActive ? activeColor : inactiveColor,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (segment.count != null) ...[
            const SizedBox(width: 4),
            Text(
              segment.count!,
              style: AppTextStyles.buttonSmall.copyWith(
                color: isActive ? activeColor : inactiveColor,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PhaseSegment {
  final String label;
  final String? count;

  const PhaseSegment({
    required this.label,
    this.count,
  });
}
