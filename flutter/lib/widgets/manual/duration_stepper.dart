import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A duration stepper with +/- buttons for minutes and seconds.
///
/// Displays time as "M : SS" format with decrease/increase buttons on sides.
class DurationStepper extends StatelessWidget {
  final int totalSeconds;
  final ValueChanged<int> onChanged;
  final int minSeconds;
  final int maxSeconds;
  final int step;

  const DurationStepper({
    super.key,
    required this.totalSeconds,
    required this.onChanged,
    this.minSeconds = 0,
    this.maxSeconds = 600, // 10 minutes max
    this.step = 15,
  });

  int get minutes => totalSeconds ~/ 60;
  int get seconds => totalSeconds % 60;

  void _decrease() {
    final newValue = totalSeconds - step;
    if (newValue >= minSeconds) {
      onChanged(newValue);
    }
  }

  void _increase() {
    final newValue = totalSeconds + step;
    if (newValue <= maxSeconds) {
      onChanged(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Decrease button
        _StepperButton(
          icon: Icons.remove,
          onTap: totalSeconds > minSeconds ? _decrease : null,
        ),
        const SizedBox(width: 16),
        // Time display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$minutes',
                style: AppTextStyles.h2,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ':',
                  style: AppTextStyles.h2,
                ),
              ),
              Text(
                seconds.toString().padLeft(2, '0'),
                style: AppTextStyles.h2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Increase button
        _StepperButton(
          icon: Icons.add,
          onTap: totalSeconds < maxSeconds ? _increase : null,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Icon(
          icon,
          color: isEnabled ? AppColors.textSecondary : AppColors.textMuted,
        ),
      ),
    );
  }
}
