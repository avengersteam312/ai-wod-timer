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

  // Called when user taps on bottom tab - clears workout to show default content
  void _onTabTapped(int index) {
    final workout = context.read<WorkoutProvider>();

    // Clear workout when tapping any tab (to show default content)
    if (workout.currentWorkout != null) {
      workout.clearWorkout();
    }

    setState(() {
      _currentIndex = index;
    });
  }

  // Called programmatically to show timer - does NOT clear workout
  void _navigateToTimer() {
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

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ManualTimerScreen(onNavigateToTimer: _navigateToTimer),
          TimerScreen(onNavigateToManual: _navigateToManual),
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
          // Only hide highlight when timer is actively running
          selectedItemColor: hasActiveTimer
              ? AppColors.textMuted
              : AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.timer_outlined),
              activeIcon: Icon(hasActiveTimer ? Icons.timer_outlined : Icons.timer),
              label: 'Manual',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(hasActiveTimer ? Icons.auto_awesome_outlined : Icons.auto_awesome),
              label: 'AI Timer',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history_outlined),
              activeIcon: Icon(hasActiveTimer ? Icons.history_outlined : Icons.history),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
