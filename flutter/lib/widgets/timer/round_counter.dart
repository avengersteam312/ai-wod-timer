import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Displays current round progress
/// Can be styled as text, badge, or progress indicator
class RoundCounter extends StatelessWidget {
  final int currentRound;
  final int totalRounds;
  final RoundCounterStyle style;
  final Color? activeColor;

  const RoundCounter({
    super.key,
    required this.currentRound,
    required this.totalRounds,
    this.style = RoundCounterStyle.text,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case RoundCounterStyle.text:
        return _buildTextStyle();
      case RoundCounterStyle.badge:
        return _buildBadgeStyle();
      case RoundCounterStyle.dots:
        return _buildDotsStyle();
      case RoundCounterStyle.progress:
        return _buildProgressStyle();
    }
  }

  Widget _buildTextStyle() {
    return Text(
      'Round $currentRound of $totalRounds',
      style: AppTextStyles.body.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildBadgeStyle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.loop,
            size: 16,
            color: activeColor ?? AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$currentRound / $totalRounds',
            style: AppTextStyles.buttonSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotsStyle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalRounds, (index) {
        final isCompleted = index < currentRound;
        final isCurrent = index == currentRound - 1;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isCurrent ? 12 : 8,
            height: isCurrent ? 12 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? (activeColor ?? AppColors.primary)
                  : AppColors.border,
              border: isCurrent
                  ? Border.all(
                      color: activeColor ?? AppColors.primary,
                      width: 2,
                    )
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildProgressStyle() {
    final progress = totalRounds > 0 ? currentRound / totalRounds : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Round $currentRound',
              style: AppTextStyles.bodySmall.copyWith(
                color: activeColor ?? AppColors.primary,
              ),
            ),
            Text(
              'of $totalRounds',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(
              activeColor ?? AppColors.primary,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

enum RoundCounterStyle {
  text,
  badge,
  dots,
  progress,
}
