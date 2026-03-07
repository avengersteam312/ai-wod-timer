import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Utility class for showing consistent notifications across the app.
///
/// Shows as a bottom sheet that covers the navigation bar, matching
/// the style of the save template success/error messages.
class AppSnackBar {
  AppSnackBar._();

  /// Shows a success notification with green background
  static void showSuccess(BuildContext context, String message, {IconData icon = Icons.check_circle}) {
    _show(context, message: message, icon: icon, backgroundColor: AppColors.success);
  }

  /// Shows an info notification with blue background
  static void showInfo(BuildContext context, String message, {IconData icon = Icons.info}) {
    _show(context, message: message, icon: icon, backgroundColor: AppColors.info);
  }

  /// Shows an error notification with red background
  static void showError(BuildContext context, String message, {IconData icon = Icons.error}) {
    _show(context, message: message, icon: icon, backgroundColor: AppColors.error);
  }

  /// Shows a warning notification with amber background
  static void showWarning(BuildContext context, String message, {IconData icon = Icons.warning}) {
    _show(context, message: message, icon: icon, backgroundColor: AppColors.warning);
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Auto-close after duration
        Future.delayed(duration, () {
          try {
            if (ctx.mounted && Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          } catch (_) {
            // Context no longer valid, ignore
          }
        });

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: backgroundColor,
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
