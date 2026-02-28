import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Card displaying workout information
/// Can show movements, notes, and other details
class WorkoutInfoCard extends StatelessWidget {
  final String? title;
  final List<WorkoutInfoItem> items;
  final EdgeInsets padding;
  final bool showDividers;

  const WorkoutInfoCard({
    super.key,
    this.title,
    required this.items,
    this.padding = const EdgeInsets.all(16),
    this.showDividers = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: padding.copyWith(bottom: 0),
              child: Text(
                title!,
                style: AppTextStyles.h4,
              ),
            ),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;

            return Column(
              children: [
                Padding(
                  padding: padding,
                  child: _buildItem(item),
                ),
                if (showDividers && !isLast)
                  const Divider(height: 1, color: AppColors.border),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItem(WorkoutInfoItem item) {
    return Row(
      children: [
        if (item.icon != null) ...[
          Icon(
            item.icon,
            size: 20,
            color: item.iconColor ?? AppColors.textMuted,
          ),
          const SizedBox(width: 12),
        ],
        if (item.leading != null) ...[
          item.leading!,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: AppTextStyles.body.copyWith(
                  color: item.labelColor ?? AppColors.textPrimary,
                ),
              ),
              if (item.subtitle != null)
                Text(
                  item.subtitle!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (item.value != null)
          Text(
            item.value!,
            style: AppTextStyles.body.copyWith(
              color: item.valueColor ?? AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (item.trailing != null) item.trailing!,
      ],
    );
  }
}

class WorkoutInfoItem {
  final String label;
  final String? subtitle;
  final String? value;
  final IconData? icon;
  final Color? iconColor;
  final Color? labelColor;
  final Color? valueColor;
  final Widget? leading;
  final Widget? trailing;

  const WorkoutInfoItem({
    required this.label,
    this.subtitle,
    this.value,
    this.icon,
    this.iconColor,
    this.labelColor,
    this.valueColor,
    this.leading,
    this.trailing,
  });
}

/// Simple stats row for displaying timer statistics
class TimerStatsRow extends StatelessWidget {
  final List<TimerStat> stats;
  final MainAxisAlignment alignment;

  const TimerStatsRow({
    super.key,
    required this.stats,
    this.alignment = MainAxisAlignment.spaceEvenly,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: stats.map((stat) => _StatItem(stat: stat)).toList(),
    );
  }
}

class _StatItem extends StatelessWidget {
  final TimerStat stat;

  const _StatItem({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stat.value,
          style: AppTextStyles.h3.copyWith(
            color: stat.valueColor ?? AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          stat.label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class TimerStat {
  final String label;
  final String value;
  final Color? valueColor;

  const TimerStat({
    required this.label,
    required this.value,
    this.valueColor,
  });
}
