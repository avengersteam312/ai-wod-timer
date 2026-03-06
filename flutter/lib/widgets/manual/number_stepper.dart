import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// A number stepper with +/- buttons for single values.
///
/// Displays a number with decrease/increase buttons on sides.
/// Tap on the value to edit it inline with numeric keyboard.
class NumberStepper extends StatefulWidget {
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

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  bool _editing = false;
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _editing) {
      _submitValue();
    }
  }

  int _getCurrentValue() {
    // If editing, use the current edited value
    if (_editing) {
      return int.tryParse(_controller.text) ?? widget.value;
    }
    return widget.value;
  }

  void _decrease() {
    final current = _getCurrentValue();
    final newValue = current - widget.step;
    if (newValue >= widget.minValue) {
      widget.onChanged(newValue);
      _updateControllerIfEditing(newValue);
    }
  }

  void _increase() {
    final current = _getCurrentValue();
    final newValue = current + widget.step;
    if (newValue <= widget.maxValue) {
      widget.onChanged(newValue);
      _updateControllerIfEditing(newValue);
    }
  }

  void _updateControllerIfEditing(int newValue) {
    if (_editing) {
      _controller.text = newValue.toString();
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  void _startEditing() {
    final wasEditing = _editing;
    setState(() {
      _editing = true;
      if (!wasEditing) {
        _controller.text = widget.value.toString();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _submitValue() {
    if (!_editing) return;
    final parsed = int.tryParse(_controller.text);
    if (parsed != null) {
      final clamped = parsed.clamp(widget.minValue, widget.maxValue);
      widget.onChanged(clamped);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepperButton(
          icon: Icons.remove,
          onTap: widget.value > widget.minValue ? _decrease : null,
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: _startEditing,
          child: Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _editing ? _controller.text : '${widget.value}',
                    style: AppTextStyles.h2.copyWith(
                      color: _editing ? AppColors.primary : null,
                    ),
                  ),
                // Hidden EditableText for keyboard input
                if (_editing)
                  SizedBox(
                    width: 0,
                    height: 0,
                    child: EditableText(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 1),
                      cursorColor: Colors.transparent,
                      backgroundCursorColor: Colors.transparent,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableInteractiveSelection: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      onSubmitted: (_) => _submitValue(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                if (widget.suffix != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.suffix!,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ),
        const SizedBox(width: 16),
        _StepperButton(
          icon: Icons.add,
          onTap: widget.value < widget.maxValue ? _increase : null,
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
