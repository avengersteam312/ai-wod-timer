import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable scaffold structure for timer screens
/// Provides consistent layout with optional sections
class TimerScaffold extends StatelessWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget timerSection;
  final Widget? indicatorSection;
  final Widget controlsSection;
  final Widget? expandableSection;
  final Widget? completedSection;
  final bool isCompleted;
  final EdgeInsets padding;
  final Widget? floatingWidget;

  const TimerScaffold({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    required this.timerSection,
    this.indicatorSection,
    required this.controlsSection,
    this.expandableSection,
    this.completedSection,
    this.isCompleted = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.floatingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: padding,
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        // Timer display section
                        timerSection,
                        const SizedBox(height: 24),
                        // Phase indicator (round/rest toggle)
                        if (indicatorSection != null) ...[
                          indicatorSection!,
                          const SizedBox(height: 32),
                        ],
                        // Controls section
                        controlsSection,
                        const SizedBox(height: 24),
                        // Expandable section (show workout)
                        if (expandableSection != null && !isCompleted)
                          expandableSection!,
                        // Completed section
                        if (isCompleted && completedSection != null) ...[
                          const SizedBox(height: 24),
                          completedSection!,
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (floatingWidget != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: floatingWidget!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Simple centered layout for timer content
class TimerCenteredLayout extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const TimerCenteredLayout({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Completion overlay/card
class CompletionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? elapsedTime;
  final VoidCallback? onNewWorkout;
  final VoidCallback? onSave;
  final bool showSaveButton;
  final Color accentColor;

  const CompletionCard({
    super.key,
    this.title = 'Workout Complete!',
    this.subtitle,
    this.elapsedTime,
    this.onNewWorkout,
    this.onSave,
    this.showSaveButton = false,
    this.accentColor = AppColors.success,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.celebration,
            size: 48,
            color: accentColor,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.h2.copyWith(
              color: accentColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (elapsedTime != null) ...[
            const SizedBox(height: 8),
            Text(
              'Total time: $elapsedTime',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (onNewWorkout != null || (showSaveButton && onSave != null)) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                if (showSaveButton && onSave != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSave,
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (onNewWorkout != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onNewWorkout,
                      child: const Text('New Workout'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
