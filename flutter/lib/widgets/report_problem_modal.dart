import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/report_service.dart';
import '../utils/snackbar_utils.dart';

/// A modal for reporting problems with AI timer parsing.
///
/// Shows category chips for the type of problem and an optional
/// text field for additional details.
class ReportProblemModal extends StatefulWidget {
  /// The original AI-parsed timer config (as JSON map)
  final Map<String, dynamic> originalParsed;

  /// The user-edited timer config (as JSON map), if different
  final Map<String, dynamic>? editedConfig;

  /// App version string
  final String appVersion;

  const ReportProblemModal({
    super.key,
    required this.originalParsed,
    this.editedConfig,
    required this.appVersion,
  });

  /// Shows the report problem modal
  static Future<bool> show({
    required BuildContext context,
    required Map<String, dynamic> originalParsed,
    Map<String, dynamic>? editedConfig,
    required String appVersion,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ReportProblemModal(
        originalParsed: originalParsed,
        editedConfig: editedConfig,
        appVersion: appVersion,
      ),
    );
    return result ?? false;
  }

  @override
  State<ReportProblemModal> createState() => _ReportProblemModalState();
}

class _ReportProblemModalState extends State<ReportProblemModal> {
  ReportKind? _selectedKind;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _selectedKind != null && !_isSubmitting;

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    try {
      await ReportService().submitReport(
        kind: _selectedKind!,
        message:
            _detailsController.text.trim().isNotEmpty ? _detailsController.text.trim() : null,
        originalParsed: widget.originalParsed,
        editedConfig: widget.editedConfig,
        appVersion: widget.appVersion,
      );

      if (mounted) {
        Navigator.pop(context, true);
        AppSnackBar.showSuccess(context, 'Thanks for the feedback!');
      }
    } on ReportException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackBar.showError(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackBar.showError(context, 'Failed to submit report');
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
          // Header
          Row(
            children: [
              const Text('Report a problem', style: AppTextStyles.h3),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category label
          Text(
            'WHAT WENT WRONG?',
            style: AppTextStyles.labelSmall.copyWith(
              letterSpacing: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          // Category chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReportKind.values.map((kind) {
              final isSelected = _selectedKind == kind;
              return ChoiceChip(
                label: Text(kind.displayLabel),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedKind = selected ? kind : null;
                  });
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.3),
                backgroundColor: AppColors.inputBackground,
                labelStyle: AppTextStyles.body.copyWith(
                  color: isSelected ? AppColors.primaryLight : AppColors.textSecondary,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Details text field
          Text(
            'DETAILS (optional)',
            style: AppTextStyles.labelSmall.copyWith(
              letterSpacing: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _detailsController,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'What should it have been?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSubmit ? _handleSubmit : null,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : const Text('Submit Report'),
            ),
          ),
        ],
      ),
    );
  }
}
