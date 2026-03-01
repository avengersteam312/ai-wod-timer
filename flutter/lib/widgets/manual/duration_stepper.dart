import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// A duration stepper with +/- buttons for minutes and seconds.
///
/// Displays time as "M : SS" format with decrease/increase buttons on sides.
/// Tap on the time to enter it directly via numeric keyboard.
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

  void _showInputDialog(BuildContext context) {
    final minutesController = TextEditingController(text: minutes.toString());
    final secondsController = TextEditingController(text: seconds.toString().padLeft(2, '0'));
    final secondsFocus = FocusNode();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Enter Time', style: AppTextStyles.h3),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Minutes input
            SizedBox(
              width: 60,
              child: TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                autofocus: true,
                textAlign: TextAlign.center,
                style: AppTextStyles.h2,
                decoration: InputDecoration(
                  hintText: 'min',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) {
                  secondsFocus.requestFocus();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(':', style: AppTextStyles.h2),
            ),
            // Seconds input
            SizedBox(
              width: 60,
              child: TextField(
                controller: secondsController,
                focusNode: secondsFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                textAlign: TextAlign.center,
                style: AppTextStyles.h2,
                decoration: InputDecoration(
                  hintText: 'sec',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (_) {
                  _submitValue(ctx, minutesController.text, secondsController.text);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _submitValue(ctx, minutesController.text, secondsController.text),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _submitValue(BuildContext context, String minutesText, String secondsText) {
    final mins = int.tryParse(minutesText) ?? 0;
    final secs = int.tryParse(secondsText) ?? 0;
    final total = (mins * 60) + secs;
    final clamped = total.clamp(minSeconds, maxSeconds);
    onChanged(clamped);
    Navigator.pop(context);
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
        // Time display - tappable for direct input
        GestureDetector(
          onTap: () => _showInputDialog(context),
          child: Container(
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
                  style: AppTextStyles.h1.copyWith(fontSize: 48),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    ':',
                    style: AppTextStyles.h1.copyWith(fontSize: 48),
                  ),
                ),
                Text(
                  seconds.toString().padLeft(2, '0'),
                  style: AppTextStyles.h1.copyWith(fontSize: 48),
                ),
              ],
            ),
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
