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


  void _showMinutesDialog(BuildContext context) {
    final text = minutes.toString();
    final controller = TextEditingController(text: text);
    controller.selection = TextSelection(baseOffset: 0, extentOffset: text.length);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Enter Minutes', style: AppTextStyles.h3),
        content: TextField(
          controller: controller,
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
          onSubmitted: (text) {
            _submitMinutes(ctx, text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _submitMinutes(ctx, controller.text),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _submitMinutes(BuildContext context, String text) {
    final mins = int.tryParse(text) ?? 0;
    final total = (mins * 60) + seconds;
    final clamped = total.clamp(minSeconds, maxSeconds);
    onChanged(clamped);
    Navigator.pop(context);
  }

  void _showSecondsDialog(BuildContext context) {
    final text = seconds.toString().padLeft(2, '0');
    final controller = TextEditingController(text: text);
    controller.selection = TextSelection(baseOffset: 0, extentOffset: text.length);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Enter Seconds', style: AppTextStyles.h3),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          autofocus: true,
          textAlign: TextAlign.center,
          style: AppTextStyles.h2,
          decoration: InputDecoration(
            hintText: 'sec',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onSubmitted: (text) {
            _submitSeconds(ctx, text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _submitSeconds(ctx, controller.text),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _submitSeconds(BuildContext context, String text) {
    final secs = int.tryParse(text) ?? 0;
    // Clamp seconds to 0-59
    final clampedSecs = secs.clamp(0, 59);
    final total = (minutes * 60) + clampedSecs;
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
        // Time display - each part tappable separately
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minutes - tappable
              GestureDetector(
                onTap: () => _showMinutesDialog(context),
                child: Text(
                  '$minutes',
                  style: AppTextStyles.h2,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ':',
                  style: AppTextStyles.h2,
                ),
              ),
              // Seconds - tappable
              GestureDetector(
                onTap: () => _showSecondsDialog(context),
                child: Text(
                  seconds.toString().padLeft(2, '0'),
                  style: AppTextStyles.h2,
                ),
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
