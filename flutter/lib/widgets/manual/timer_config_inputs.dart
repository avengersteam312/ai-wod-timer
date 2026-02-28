import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class DurationPicker extends StatefulWidget {
  final int initialMinutes;
  final int initialSeconds;
  final String label;
  final ValueChanged<int> onChanged;

  const DurationPicker({
    super.key,
    this.initialMinutes = 0,
    this.initialSeconds = 0,
    required this.label,
    required this.onChanged,
  });

  @override
  State<DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<DurationPicker> {
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes;
    _seconds = widget.initialSeconds;
  }

  void _updateValue() {
    widget.onChanged(_minutes * 60 + _seconds);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.label,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Minutes
            Expanded(
              child: _NumberInput(
                value: _minutes,
                label: 'min',
                maxValue: 99,
                onChanged: (value) {
                  setState(() => _minutes = value);
                  _updateValue();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ':',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            // Seconds
            Expanded(
              child: _NumberInput(
                value: _seconds,
                label: 'sec',
                maxValue: 59,
                onChanged: (value) {
                  setState(() => _seconds = value);
                  _updateValue();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumberInput extends StatelessWidget {
  final int value;
  final String label;
  final int maxValue;
  final ValueChanged<int> onChanged;

  const _NumberInput({
    required this.value,
    required this.label,
    required this.maxValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Decrement
          IconButton(
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
            color: AppColors.textSecondary,
            iconSize: 20,
          ),

          // Value display
          Expanded(
            child: Column(
              children: [
                Text(
                  value.toString().padLeft(2, '0'),
                  style: AppTextStyles.h2,
                  textAlign: TextAlign.center,
                ),
                Text(
                  label,
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
          ),

          // Increment
          IconButton(
            onPressed: value < maxValue ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
            color: AppColors.textSecondary,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

class RoundsInput extends StatelessWidget {
  final int value;
  final String label;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  const RoundsInput({
    super.key,
    required this.value,
    this.label = 'Rounds',
    this.minValue = 1,
    this.maxValue = 99,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Decrement
              IconButton(
                onPressed: value > minValue ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove),
                color: AppColors.textSecondary,
              ),

              // Value
              Text(
                '$value',
                style: AppTextStyles.h2,
              ),

              // Increment
              IconButton(
                onPressed: value < maxValue ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SecondsInput extends StatefulWidget {
  final int initialValue;
  final String label;
  final int minValue;
  final int maxValue;
  final int step;
  final ValueChanged<int> onChanged;

  const SecondsInput({
    super.key,
    required this.initialValue,
    required this.label,
    this.minValue = 5,
    this.maxValue = 300,
    this.step = 5,
    required this.onChanged,
  });

  @override
  State<SecondsInput> createState() => _SecondsInputState();
}

class _SecondsInputState extends State<SecondsInput> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  String _formatSeconds(int seconds) {
    if (seconds >= 60) {
      final mins = seconds ~/ 60;
      final secs = seconds % 60;
      if (secs == 0) {
        return '${mins}m';
      }
      return '${mins}m ${secs}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.label,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Decrement
              IconButton(
                onPressed: _value > widget.minValue
                    ? () {
                        setState(() => _value -= widget.step);
                        widget.onChanged(_value);
                      }
                    : null,
                icon: const Icon(Icons.remove),
                color: AppColors.textSecondary,
              ),

              // Value
              Text(
                _formatSeconds(_value),
                style: AppTextStyles.h3,
              ),

              // Increment
              IconButton(
                onPressed: _value < widget.maxValue
                    ? () {
                        setState(() => _value += widget.step);
                        widget.onChanged(_value);
                      }
                    : null,
                icon: const Icon(Icons.add),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TextInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const TextInput({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
          ),
        ),
      ],
    );
  }
}
