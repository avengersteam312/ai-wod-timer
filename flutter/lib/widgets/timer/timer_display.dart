import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Central timer display with label, time, and optional sublabel
/// Can be used inside or outside a ring
class TimerDisplay extends StatelessWidget {
  final String time;
  final String? label;
  final String? subLabel;
  final Color? labelColor;
  final double timeSize;
  final TextStyle? timeStyle;
  final TextStyle? labelStyle;
  final TextStyle? subLabelStyle;

  const TimerDisplay({
    super.key,
    required this.time,
    this.label,
    this.subLabel,
    this.labelColor,
    this.timeSize = 72,
    this.timeStyle,
    this.labelStyle,
    this.subLabelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(
            label!,
            style: labelStyle ??
                AppTextStyles.labelSmall.copyWith(
                  color: labelColor ?? AppColors.primary,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
          ),
        if (label != null) const SizedBox(height: 4),
        Text(
          time,
          style: timeStyle ??
              AppTextStyles.timerLarge.copyWith(
                fontSize: timeSize,
              ),
        ),
        if (subLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            subLabel!,
            style: subLabelStyle ??
                AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ],
    );
  }
}

/// Compact timer display for smaller spaces
class CompactTimerDisplay extends StatelessWidget {
  final String time;
  final String? label;
  final Color? labelColor;

  const CompactTimerDisplay({
    super.key,
    required this.time,
    this.label,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (labelColor ?? AppColors.primary).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label!,
              style: AppTextStyles.labelSmall.copyWith(
                color: labelColor ?? AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Text(
          time,
          style: AppTextStyles.timerMedium,
        ),
      ],
    );
  }
}
