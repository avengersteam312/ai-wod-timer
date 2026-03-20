import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../theme/app_theme.dart';
import '../services/haptics_service.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;

  const WorkoutCard({
    super.key,
    required this.workout,
    required this.onTap,
    this.onFavoriteToggle,
    this.onDelete,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticsService.instance.buttonTap();
        onTap();
      },
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    workout.name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Type and duration
                  Row(
                    children: [
                      Text(
                        workout.type.displayName,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        workout.formattedDuration,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  // Notes preview
                  if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      workout.notes!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Favorite button
            if (onFavoriteToggle != null)
              GestureDetector(
                onTap: () {
                  HapticsService.instance.buttonTap();
                  onFavoriteToggle!();
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    workout.isFavorite ? Icons.star : Icons.star_border,
                    color:
                        workout.isFavorite ? Colors.amber : AppColors.textMuted,
                    size: 22,
                  ),
                ),
              ),
            // Delete button
            if (onDelete != null)
              GestureDetector(
                onTap: () {
                  HapticsService.instance.buttonTap();
                  onDelete!();
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WorkoutCardCompact extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;

  const WorkoutCardCompact({
    super.key,
    required this.workout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticsService.instance.buttonTap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: AppColors.primary,
                size: 24,
              ),
            ),

            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        workout.type.displayName,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        workout.formattedDuration,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
