import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// A duration stepper with +/- buttons for minutes and seconds.
///
/// Displays time as "M : SS" format with decrease/increase buttons on sides.
/// Tap on minutes or seconds to edit them inline.
class DurationStepper extends StatefulWidget {
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
    this.maxSeconds = 600,
    this.step = 15,
  });

  @override
  State<DurationStepper> createState() => _DurationStepperState();
}

class _DurationStepperState extends State<DurationStepper> {
  bool _editingMinutes = false;
  bool _editingSeconds = false;
  late TextEditingController _minutesController;
  late TextEditingController _secondsController;
  final FocusNode _minutesFocus = FocusNode();
  final FocusNode _secondsFocus = FocusNode();

  int get minutes => widget.totalSeconds ~/ 60;
  int get seconds => widget.totalSeconds % 60;

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController();
    _secondsController = TextEditingController();
    _minutesFocus.addListener(_onMinutesFocusChange);
    _secondsFocus.addListener(_onSecondsFocusChange);
  }

  @override
  void dispose() {
    _minutesFocus.removeListener(_onMinutesFocusChange);
    _secondsFocus.removeListener(_onSecondsFocusChange);
    _minutesController.dispose();
    _secondsController.dispose();
    _minutesFocus.dispose();
    _secondsFocus.dispose();
    super.dispose();
  }

  void _onMinutesFocusChange() {
    if (!_minutesFocus.hasFocus && _editingMinutes) {
      _submitMinutes();
    }
  }

  void _onSecondsFocusChange() {
    if (!_secondsFocus.hasFocus && _editingSeconds) {
      _submitSeconds();
    }
  }

  int _getCurrentTotalSeconds() {
    // If editing, use the current edited values
    final mins = _editingMinutes
        ? (int.tryParse(_minutesController.text) ?? minutes)
        : minutes;
    final secs = _editingSeconds
        ? (int.tryParse(_secondsController.text) ?? seconds)
        : seconds;
    return (mins * 60) + secs;
  }

  void _decrease() {
    final current = _getCurrentTotalSeconds();
    final newValue = current - widget.step;
    if (newValue >= widget.minSeconds) {
      widget.onChanged(newValue);
      _updateControllersIfEditing(newValue);
    }
  }

  void _increase() {
    final current = _getCurrentTotalSeconds();
    final newValue = current + widget.step;
    if (newValue <= widget.maxSeconds) {
      widget.onChanged(newValue);
      _updateControllersIfEditing(newValue);
    }
  }

  void _updateControllersIfEditing(int newTotalSeconds) {
    final newMinutes = newTotalSeconds ~/ 60;
    final newSeconds = newTotalSeconds % 60;
    if (_editingMinutes) {
      _minutesController.text = newMinutes.toString();
      _minutesController.selection =
          TextSelection.collapsed(offset: _minutesController.text.length);
    }
    if (_editingSeconds) {
      _secondsController.text = newSeconds.toString().padLeft(2, '0');
      _secondsController.selection =
          TextSelection.collapsed(offset: _secondsController.text.length);
    }
  }

  void _startEditingMinutes() {
    final wasEditing = _editingMinutes;
    setState(() {
      _editingMinutes = true;
      if (!wasEditing) {
        _minutesController.text = minutes.toString();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _minutesFocus.requestFocus();
      _minutesController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _minutesController.text.length,
      );
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _startEditingSeconds() {
    final wasEditing = _editingSeconds;
    setState(() {
      _editingSeconds = true;
      if (!wasEditing) {
        _secondsController.text = seconds.toString().padLeft(2, '0');
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _secondsFocus.requestFocus();
      _secondsController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _secondsController.text.length,
      );
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void _submitMinutes() {
    if (!_editingMinutes) return;
    final mins = int.tryParse(_minutesController.text) ?? 0;
    final total = (mins * 60) + seconds;
    final clamped = total.clamp(widget.minSeconds, widget.maxSeconds);
    widget.onChanged(clamped);
    setState(() => _editingMinutes = false);
  }

  void _submitSeconds() {
    if (!_editingSeconds) return;
    final secs = int.tryParse(_secondsController.text) ?? 0;
    final clampedSecs = secs.clamp(0, 59);
    final total = (minutes * 60) + clampedSecs;
    final clamped = total.clamp(widget.minSeconds, widget.maxSeconds);
    widget.onChanged(clamped);
    setState(() => _editingSeconds = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepperButton(
          icon: Icons.remove,
          onTap: widget.totalSeconds > widget.minSeconds ? _decrease : null,
        ),
        const SizedBox(width: 16),
        Container(
          width: 130,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minutes
              _buildEditableField(
                displayValue: '$minutes',
                isEditing: _editingMinutes,
                controller: _minutesController,
                focusNode: _minutesFocus,
                onTap: _startEditingMinutes,
                onSubmit: _submitMinutes,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(':', style: AppTextStyles.h2),
              ),
              // Seconds
              _buildEditableField(
                displayValue: seconds.toString().padLeft(2, '0'),
                isEditing: _editingSeconds,
                controller: _secondsController,
                focusNode: _secondsFocus,
                onTap: _startEditingSeconds,
                onSubmit: _submitSeconds,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _StepperButton(
          icon: Icons.add,
          onTap: widget.totalSeconds < widget.maxSeconds ? _increase : null,
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required String displayValue,
    required bool isEditing,
    required TextEditingController controller,
    required FocusNode focusNode,
    required VoidCallback onTap,
    required VoidCallback onSubmit,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: Text(
                isEditing ? controller.text : displayValue,
                style: AppTextStyles.h2.copyWith(
                  color: isEditing ? AppColors.primary : null,
                ),
              ),
            ),
          ),
          // Hidden EditableText for keyboard input
          if (isEditing)
            SizedBox(
              width: 0,
              height: 0,
              child: EditableText(
                controller: controller,
                focusNode: focusNode,
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
                onSubmitted: (_) => onSubmit(),
                onChanged: (_) => setState(() {}),
              ),
            ),
        ],
      ),
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
            color: isEnabled
                ? AppColors.border
                : AppColors.border.withValues(alpha: 0.5),
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
