import 'package:flutter/material.dart';
import '../../models/movement.dart';
import '../../theme/app_theme.dart';

/// Movement list showing workout progress.
///
/// Design from Penpot:
/// - Background: cardBackground (#1a1a1a)
/// - Vertical padding: 12
/// - Row gap: 4 between items
/// - Header: "Workout Progress"
class MovementList extends StatelessWidget {
  final List<Movement> movements;
  final int currentIndex;
  final VoidCallback? onMovementTap;

  const MovementList({
    super.key,
    required this.movements,
    this.currentIndex = 0,
    this.onMovementTap,
  });

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Workout Progress',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Movement items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: movements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final movement = movements[index];
              final isCurrent = index == currentIndex;
              final isCompleted = index < currentIndex;

              return MovementListItem(
                movement: movement,
                isCurrent: isCurrent,
                isCompleted: isCompleted,
                roundLabel: 'R${index + 1}',
                onTap: onMovementTap,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Individual movement item in the list.
///
/// Design shows:
/// - Round indicator (green dot for current/completed, gray for pending)
/// - Round label (R1, R2, etc.)
/// - Movement name
class MovementListItem extends StatelessWidget {
  final Movement movement;
  final bool isCurrent;
  final bool isCompleted;
  final String roundLabel;
  final VoidCallback? onTap;

  const MovementListItem({
    super.key,
    required this.movement,
    this.isCurrent = false,
    this.isCompleted = false,
    required this.roundLabel,
    this.onTap,
  });

  Color get _indicatorColor {
    if (isCurrent) return AppColors.warning;
    if (isCompleted) return AppColors.success;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            // Status indicator dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _indicatorColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Round label
            Text(
              roundLabel,
              style: AppTextStyles.bodySmall.copyWith(
                color: isCurrent ? AppColors.warning : AppColors.textMuted,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 12),
            // Movement text
            Expanded(
              child: Text(
                movement.displayText,
                style: AppTextStyles.body.copyWith(
                  color: isCompleted
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Current movement display card.
///
/// Design from Penpot:
/// - Background: cardBackground (#1a1a1a)
/// - Border radius: 12
/// - Vertical padding: 16
/// - Centered content with label, name, and details
class CurrentMovementDisplay extends StatelessWidget {
  final Movement? current;
  final Movement? next;

  const CurrentMovementDisplay({
    super.key,
    this.current,
    this.next,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Current movement card
        if (current != null) _buildCurrentCard(),
        // Next preview
        if (next != null) ...[
          const SizedBox(height: 8),
          _buildNextPreview(),
        ],
      ],
    );
  }

  Widget _buildCurrentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'CURRENT MOVEMENT',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            current!.displayText,
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          if (current!.notes != null && current!.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              current!.notes!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextPreview() {
    return Container(
      width: double.infinity,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            'NEXT:',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              next!.shortDisplayText,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
