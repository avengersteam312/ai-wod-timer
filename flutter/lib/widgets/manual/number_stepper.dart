import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A number stepper with +/- buttons for single values.
///
/// Displays a number with decrease/increase buttons on sides.
class NumberStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int minValue;
  final int maxValue;
  final int step;
  final String? suffix;

  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 1,
    this.maxValue = 99,
    this.step = 1,
    this.suffix,
  });

  void _decrease() {
    final newValue = value - step;
    if (newValue >= minValue) {
      onChanged(newValue);
    }
  }

  void _increase() {
    final newValue = value + step;
    if (newValue <= maxValue) {
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
          onTap: value > minValue ? _decrease : null,
        ),
        const SizedBox(width: 16),
        // Value display
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
                '$value',
                style: AppTextStyles.h2,
              ),
              if (suffix != null) ...[
                const SizedBox(width: 8),
                Text(
                  suffix!,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Increase button
        _StepperButton(
          icon: Icons.add,
          onTap: value < maxValue ? _increase : null,
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
