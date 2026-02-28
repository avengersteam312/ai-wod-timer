import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A quick select chip for preset values.
///
/// Used for quick duration selection in timers.
class QuickSelectChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const QuickSelectChip({
    super.key,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: isSelected ? AppColors.textPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// A horizontal scrollable slider of quick select chips.
class QuickSelectGrid extends StatelessWidget {
  final List<QuickSelectOption> options;
  final int? selectedValue;
  final ValueChanged<int> onSelected;

  const QuickSelectGrid({
    super.key,
    required this.options,
    required this.onSelected,
    this.selectedValue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              right: index < options.length - 1 ? 8 : 0,
            ),
            child: QuickSelectChip(
              label: option.label,
              isSelected: selectedValue == option.value,
              onTap: () => onSelected(option.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Represents a quick select option with a label and value.
class QuickSelectOption {
  final String label;
  final int value;

  const QuickSelectOption({
    required this.label,
    required this.value,
  });
}

