import 'package:flutter/material.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';
import '../../services/haptics_service.dart';

class TimerTypeSelector extends StatefulWidget {
  final WorkoutType selectedType;
  final ValueChanged<WorkoutType> onTypeChanged;
  final List<WorkoutType> types;

  const TimerTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
    this.types = const [
      WorkoutType.restTimer,
      WorkoutType.forTime,
      WorkoutType.amrap,
      WorkoutType.emom,
      WorkoutType.tabata,
      WorkoutType.workRest,
      WorkoutType.customInterval,
    ],
  });

  @override
  State<TimerTypeSelector> createState() => _TimerTypeSelectorState();
}

class _TimerTypeSelectorState extends State<TimerTypeSelector> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _itemKeys = [];

  @override
  void initState() {
    super.initState();
    _itemKeys.addAll(List.generate(widget.types.length, (_) => GlobalKey()));
    // Scroll to selected item after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(TimerTypeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedType != widget.selectedType) {
      _scrollToSelected();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    final selectedIndex = widget.types.indexOf(widget.selectedType);
    if (selectedIndex < 0 || selectedIndex >= _itemKeys.length) return;

    final key = _itemKeys[selectedIndex];
    final context = key.currentContext;
    if (context == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final screenWidth = MediaQuery.of(this.context).size.width;
    final itemWidth = box.size.width;

    // Calculate position to center the item
    double targetOffset = 0;
    for (int i = 0; i < selectedIndex; i++) {
      final itemKey = _itemKeys[i];
      final itemContext = itemKey.currentContext;
      if (itemContext != null) {
        final itemBox = itemContext.findRenderObject() as RenderBox?;
        if (itemBox != null) {
          targetOffset += itemBox.size.width + 8; // 8 is separator width
        }
      }
    }

    // Center the item
    targetOffset -= (screenWidth - itemWidth) / 2 - 16; // 16 is horizontal padding
    targetOffset = targetOffset.clamp(0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = widget.types[index];
          final isSelected = type == widget.selectedType;

          return _TypeChip(
            key: _itemKeys[index],
            label: type.displayName,
            isSelected: isSelected,
            onTap: () {
              HapticsService.instance.selectionChanged();
              widget.onTypeChanged(type);
            },
          );
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonSmall.copyWith(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class TimerTypeGrid extends StatelessWidget {
  final WorkoutType selectedType;
  final ValueChanged<WorkoutType> onTypeChanged;

  const TimerTypeGrid({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final types = [
      (WorkoutType.stopwatch, Icons.timer, 'Stopwatch'),
      (WorkoutType.amrap, Icons.repeat, 'AMRAP'),
      (WorkoutType.emom, Icons.schedule, 'EMOM'),
      (WorkoutType.tabata, Icons.flash_on, 'Tabata'),
      (WorkoutType.workRest, Icons.fitness_center, 'Work/Rest'),
      (WorkoutType.restTimer, Icons.pause_circle, 'Rest Timer'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final (type, icon, label) = types[index];
        final isSelected = type == selectedType;

        return _TypeGridItem(
          icon: icon,
          label: label,
          isSelected: isSelected,
          onTap: () {
            HapticsService.instance.selectionChanged();
            onTypeChanged(type);
          },
        );
      },
    );
  }
}

class _TypeGridItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeGridItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha:0.15)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
