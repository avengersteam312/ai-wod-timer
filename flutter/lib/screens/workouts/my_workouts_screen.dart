import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/workout.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../ui_test_keys.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/workout_card.dart';

class MyWorkoutsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToTimer;
  final SyncService? syncService;
  final Future<List<Workout>> Function(String userId)? loadWorkouts;
  final Future<void> Function(Workout workout)? updateWorkout;
  final Future<void> Function(String workoutId)? deleteWorkout;

  const MyWorkoutsScreen({
    super.key,
    this.onNavigateToTimer,
    this.syncService,
    this.loadWorkouts,
    this.updateWorkout,
    this.deleteWorkout,
  });

  @override
  State<MyWorkoutsScreen> createState() => _MyWorkoutsScreenState();
}

class _MyWorkoutsScreenState extends State<MyWorkoutsScreen> {
  bool _isLoading = false;
  List<Workout> _workouts = [];
  String? _error;

  SyncService get _syncService => widget.syncService ?? SyncService();

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id ?? 'anonymous';

      final workouts = await (widget.loadWorkouts?.call(userId) ??
          _syncService.getWorkouts(userId));

      setState(() {
        _workouts = workouts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load templates';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(Workout workout) async {
    final updatedWorkout = workout.copyWith(
      isFavorite: !workout.isFavorite,
    );

    try {
      await (widget.updateWorkout?.call(updatedWorkout) ??
          _syncService.updateWorkout(updatedWorkout));
      setState(() {
        final index = _workouts.indexWhere((w) => w.id == workout.id);
        if (index != -1) {
          _workouts[index] = updatedWorkout;
        }
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to update timer');
      }
    }
  }

  void _startWorkout(Workout workout) {
    final workoutProvider = context.read<WorkoutProvider>();
    workoutProvider.setWorkout(workout, fromSavedWorkoutId: workout.id);

    // Navigate to timer tab
    widget.onNavigateToTimer?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: UiTestKeys.myWorkoutsScreen,
      appBar: AppBar(
        title: const Text('Saved Timers'),
        actions: [
          IconButton(
            key: UiTestKeys.myWorkoutsRefreshButton,
            onPressed: _loadWorkouts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_workouts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadWorkouts,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _workouts.length,
        itemBuilder: (context, index) {
          final workout = _workouts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: UiTestKeys.myWorkout(workout.id),
              direction: DismissDirection.endToStart,
              dismissThresholds: const {DismissDirection.endToStart: 0.5},
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Template'),
                        content: Text(
                            'Are you sure you want to delete "${workout.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
              },
              onDismissed: (direction) async {
                final removedIndex =
                    _workouts.indexWhere((w) => w.id == workout.id);
                if (removedIndex == -1) return;

                final removedWorkout = _workouts[removedIndex];
                setState(() {
                  _workouts.removeAt(removedIndex);
                });

                try {
                  await (widget.deleteWorkout?.call(workout.id) ??
                      _syncService.deleteWorkout(workout.id));
                  if (!context.mounted) return;
                  AppSnackBar.showSuccess(context, 'Template deleted');
                } catch (e) {
                  if (!mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      if (!_workouts.any((w) => w.id == removedWorkout.id)) {
                        final insertIndex = removedIndex.clamp(
                          0,
                          _workouts.length,
                        );
                        _workouts.insert(insertIndex, removedWorkout);
                      }
                    });
                  });
                  if (!context.mounted) return;
                  AppSnackBar.showError(context, 'Failed to delete template');
                }
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete,
                  color: AppColors.textPrimary,
                ),
              ),
              child: WorkoutCard(
                workout: workout,
                onTap: () => _startWorkout(workout),
                onFavoriteToggle: () => _toggleFavorite(workout),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fitness_center,
                size: 40,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Workouts Yet',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 8),
            Text(
              'Your saved workouts will appear here.\nGo to the Timer tab to create your first workout.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Please try again',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadWorkouts,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
