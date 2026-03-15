import 'package:flutter/material.dart';
import '../ui_test_keys.dart';
import '../theme/app_theme.dart';
import '../utils/workout_name.dart';
import '../utils/snackbar_utils.dart';

/// A reusable modal for saving workouts as templates.
///
/// Shows a bottom sheet with a text field for the template name,
/// Cancel and Save buttons, and handles loading state.
class SaveTemplateModal extends StatefulWidget {
  /// Default name to show in the text field
  final String defaultName;

  /// Called to check if name is already taken. Returns true if taken.
  final Future<bool> Function(String name)? onCheckNameTaken;

  /// Called when user confirms save. Should return true if save succeeded.
  final Future<bool> Function(String name) onSave;

  /// Called after successful save (e.g., to show snackbar)
  final VoidCallback? onSaveSuccess;

  const SaveTemplateModal({
    super.key,
    required this.defaultName,
    this.onCheckNameTaken,
    required this.onSave,
    this.onSaveSuccess,
  });

  /// Shows the save template modal and returns true if saved successfully
  static Future<bool> show({
    required BuildContext context,
    required String defaultName,
    Future<bool> Function(String name)? onCheckNameTaken,
    required Future<bool> Function(String name) onSave,
    VoidCallback? onSaveSuccess,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SaveTemplateModal(
        defaultName: defaultName,
        onCheckNameTaken: onCheckNameTaken,
        onSave: onSave,
        onSaveSuccess: onSaveSuccess,
      ),
    );
    return result ?? false;
  }

  @override
  State<SaveTemplateModal> createState() => _SaveTemplateModalState();
}

class _SaveTemplateModalState extends State<SaveTemplateModal> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final rawName = _controller.text.trim();
    if (rawName.isEmpty) return;

    final name = rawName.length > maxWorkoutNameLength
        ? rawName.substring(0, maxWorkoutNameLength)
        : rawName;

    setState(() => _isSaving = true);

    try {
      // Check if name is taken
      if (widget.onCheckNameTaken != null) {
        final taken = await widget.onCheckNameTaken!(name);
        if (taken) {
          if (mounted) {
            Navigator.pop(context, false);
            AppSnackBar.showError(context, 'Name already exists');
          }
          return;
        }
      }

      // Save
      final success = await widget.onSave(name);

      if (mounted) {
        Navigator.pop(context, success);
        if (success) {
          AppSnackBar.showInfo(context, 'Saved! Find in dashboard.');
          widget.onSaveSuccess?.call();
        } else {
          AppSnackBar.showError(context, 'Save failed');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, false);
        AppSnackBar.showError(context, 'Save failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Save as template?', style: AppTextStyles.h3),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Timer name', style: AppTextStyles.label),
          const SizedBox(height: 8),
          TextField(
            key: UiTestKeys.saveTemplateNameField,
            controller: _controller,
            maxLength: maxWorkoutNameLength,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter timer name',
            ),
            onSubmitted: (_) => _handleSave(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: UiTestKeys.saveTemplateCancelButton,
                  onPressed:
                      _isSaving ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: UiTestKeys.saveTemplateSubmitButton,
                  onPressed: _isSaving || _controller.text.trim().isEmpty
                      ? null
                      : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
