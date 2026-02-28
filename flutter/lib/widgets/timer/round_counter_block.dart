import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Round counter block displaying ROUND X/Y and REST X/Y side by side
/// Similar to the web frontend RoundCounterBlock component
class RoundCounterBlock extends StatelessWidget {
  final int currentWorkRound;
  final int totalWorkRounds;
  final int currentRestRound;
  final int totalRestRounds;
  final bool isWorkPhase;
  final bool isRestPhase;
  final bool isInfinite;

  const RoundCounterBlock({
    super.key,
    required this.currentWorkRound,
    required this.totalWorkRounds,
    required this.currentRestRound,
    required this.totalRestRounds,
    this.isWorkPhase = false,
    this.isRestPhase = false,
    this.isInfinite = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Work Rounds
          _buildCounter(
            label: 'ROUND',
            current: currentWorkRound,
            total: totalWorkRounds,
            isActive: isWorkPhase,
            activeColor: AppColors.timerWork,
          ),

          // Divider
          Container(
            width: 1,
            height: 32,
            color: AppColors.border,
          ),

          // Rest Rounds
          _buildCounter(
            label: 'REST',
            current: currentRestRound,
            total: totalRestRounds,
            isActive: isRestPhase,
            activeColor: AppColors.timerRest,
          ),
        ],
      ),
    );
  }

  Widget _buildCounter({
    required String label,
    required int current,
    required int total,
    required bool isActive,
    required Color activeColor,
  }) {
    final color = isActive ? activeColor : AppColors.textPrimary;
    final totalDisplay = isInfinite ? '\u221E' : '$total';

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 0.5,
      ),
      child: Text('$label $current/$totalDisplay'),
    );
  }
}
