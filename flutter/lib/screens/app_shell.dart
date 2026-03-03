import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import 'timer/timer_screen.dart';
import 'manual/manual_timer_screen.dart';
import 'history/history_screen.dart';

/// Main app shell with bottom navigation.
///
/// Tabs (3 tabs):
/// 1. Manual - Manual timer configuration
/// 2. AI Timer - AI-powered workout parsing (default tab)
/// 3. History - Workout history
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Start on AI Timer tab (middle)
  int _currentIndex = 1;

  // Called when user taps on bottom tab - allows switching without clearing timer
  void _onTabTapped(int index) {
    final workout = context.read<WorkoutProvider>();

    // If tapping AI Timer tab while already on it with active timer, toggle views
    if (index == 1 && _currentIndex == 1 && workout.currentWorkout != null) {
      workout.toggleInputOverride();
      return;
    }

    // If coming back to AI Timer tab with active timer, show timer view
    if (index == 1 && _currentIndex != 1 && workout.currentWorkout != null) {
      workout.setShowInputOverride(false);
    }

    setState(() {
      _currentIndex = index;
    });
  }

  // Called programmatically to show timer - does NOT clear workout
  void _navigateToTimer() {
    final workout = context.read<WorkoutProvider>();
    workout.setShowInputOverride(false);
    setState(() {
      _currentIndex = 1; // AI Timer tab
    });
  }

  void _navigateToManual() {
    final workout = context.read<WorkoutProvider>();
    workout.clearWorkout();
    setState(() {
      _currentIndex = 0; // Manual tab
    });
  }

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutProvider>();
    final hasActiveTimer = workout.currentWorkout != null;
    final isOnTimerTab = _currentIndex == 1;
    final isShowingInput = workout.showInputOverride;
    // Show badge when timer is active and either on different tab OR showing input view
    final showTimerBadge = hasActiveTimer && (!isOnTimerTab || isShowingInput);

    // Don't highlight AI Timer tab when timer is running and showing timer view
    final shouldMuteAITimer = hasActiveTimer && isOnTimerTab && !isShowingInput;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ManualTimerScreen(onNavigateToTimer: _navigateToTimer),
          TimerScreen(
            onNavigateToManual: _navigateToManual,
            isDashboardVisible: _currentIndex == 1,
          ),
          const HistoryScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.border,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          selectedItemColor: shouldMuteAITimer
              ? AppColors.textMuted
              : AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.timer_outlined),
              activeIcon: Icon(Icons.timer),
              label: 'Manual',
            ),
            BottomNavigationBarItem(
              icon: showTimerBadge
                  ? const Badge(
                      backgroundColor: AppColors.success,
                      smallSize: 8,
                      child: Icon(Icons.dashboard_outlined),
                    )
                  : const Icon(Icons.dashboard_outlined),
              activeIcon: showTimerBadge
                  ? Badge(
                      backgroundColor: AppColors.success,
                      smallSize: 8,
                      child: Icon(
                        Icons.dashboard,
                        color: shouldMuteAITimer
                            ? AppColors.textMuted
                            : AppColors.primary,
                      ),
                    )
                  : Icon(
                      Icons.dashboard,
                      color: shouldMuteAITimer
                          ? AppColors.textMuted
                          : AppColors.primary,
                    ),
              label: showTimerBadge ? workout.formattedTime : 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
