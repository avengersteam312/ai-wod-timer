import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workout.dart';
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

  // When editing from timer, show Manual screen but keep Dashboard tab highlighted
  bool _isEditingFromTimer = false;

  // Notifier to trigger form reset in ManualTimerScreen
  final _resetNotifier = ValueNotifier<int>(0);

  // Drag-to-delete state (managed here to cover nav bar)
  bool _showDeleteZone = false;
  bool _isOverDeleteZone = false;
  void Function(Workout)? _onDeleteWorkout;


  // Called when user taps on bottom tab - allows switching without clearing timer
  void _onTabTapped(int index) {
    final workout = context.read<WorkoutProvider>();

    // If tapping Manual tab, always reset the form to start fresh
    if (index == 0) {
      _resetNotifier.value++;
    }

    // If tapping AI Timer tab while already on it with active timer, toggle views
    if (index == 1 && _currentIndex == 1 && workout.currentWorkout != null) {
      workout.toggleInputOverride();
      setState(() {
        _isEditingFromTimer = false;
      });
      return;
    }

    // Returning to Dashboard with an active workout should show the dashboard
    // with a clear resume card instead of jumping straight into the timer view.
    if (index == 1 && _currentIndex != 1 && workout.currentWorkout != null) {
      workout.setShowInputOverride(true);
    }

    setState(() {
      _isEditingFromTimer = false;
      _currentIndex = index;
    });
  }

  // Called programmatically to show timer - does NOT clear workout
  void _navigateToTimer() {
    final workout = context.read<WorkoutProvider>();
    workout.setShowInputOverride(false);
    setState(() {
      _isEditingFromTimer = false;
      _currentIndex = 1; // AI Timer tab
    });
  }

  void _navigateToManual() {
    final workout = context.read<WorkoutProvider>();
    workout.clearWorkout();
    setState(() {
      _isEditingFromTimer = false;
      _currentIndex = 0; // Manual tab
    });
  }

  void _navigateToManualForEdit() {
    // Do NOT clear workout — user wants to edit then start from Manual tab
    // Keep Dashboard tab highlighted but show Manual screen
    setState(() {
      _isEditingFromTimer = true;
      // Keep _currentIndex at 1 (Dashboard) for tab highlighting
    });
  }

  void _setShowDeleteZone(bool show, {void Function(Workout)? onDelete}) {
    setState(() {
      _showDeleteZone = show;
      _onDeleteWorkout = onDelete;
      if (!show) _isOverDeleteZone = false;
    });
  }

  void _setIsOverDeleteZone(bool isOver) {
    setState(() => _isOverDeleteZone = isOver);
  }

  void _handleDeleteDrop(Workout workout) {
    _onDeleteWorkout?.call(workout);
    _setShowDeleteZone(false);
  }

  @override
  void dispose() {
    _resetNotifier.dispose();
    super.dispose();
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

    // When editing from timer, show Manual screen but keep Dashboard tab highlighted
    final displayIndex = _isEditingFromTimer ? 0 : _currentIndex;

    return Scaffold(
      body: IndexedStack(
        index: displayIndex,
        children: [
          ManualTimerScreen(
            onNavigateToTimer: _navigateToTimer,
            resetNotifier: _resetNotifier,
          ),
          TimerScreen(
            onNavigateToManual: _navigateToManual,
            onNavigateToManualForEdit: _navigateToManualForEdit,
            isDashboardVisible: displayIndex == 1,
            onDragStateChanged: _setShowDeleteZone,
          ),
          HistoryScreen(isVisible: displayIndex == 2),
        ],
      ),
      bottomNavigationBar: _showDeleteZone
          ? DragTarget<Workout>(
              onWillAcceptWithDetails: (details) {
                _setIsOverDeleteZone(true);
                return true;
              },
              onLeave: (_) {
                _setIsOverDeleteZone(false);
              },
              onAcceptWithDetails: (details) {
                _setIsOverDeleteZone(false);
                _handleDeleteDrop(details.data);
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: AppColors.error,
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isOverDeleteZone ? Icons.delete : Icons.delete_outline,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isOverDeleteZone ? 'Release to delete' : 'Drag here to delete',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : Container(
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
