import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/workout.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/offline_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/workout_card.dart';

class MyWorkoutsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToTimer;

  const MyWorkoutsScreen({super.key, this.onNavigateToTimer});

  @override
  State<MyWorkoutsScreen> createState() => _MyWorkoutsScreenState();
}

class _MyWorkoutsScreenState extends State<MyWorkoutsScreen> {
  final OfflineStorageService _storageService = OfflineStorageService();
  bool _isLoading = false;
  List<Workout> _workouts = [];
  String? _error;

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

      final workouts = await _storageService.getWorkouts(userId);

      setState(() {
        _workouts = workouts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load workouts';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout'),
        content: Text('Are you sure you want to delete "${workout.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _storageService.deleteWorkout(workout.id);
        setState(() {
          _workouts.removeWhere((w) => w.id == workout.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workout deleted'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete workout'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleFavorite(Workout workout) async {
    final updatedWorkout = workout.copyWith(
      isFavorite: !workout.isFavorite,
    );

    try {
      await _storageService.saveWorkout(updatedWorkout);
      setState(() {
        final index = _workouts.indexWhere((w) => w.id == workout.id);
        if (index != -1) {
          _workouts[index] = updatedWorkout;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update workout'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _startWorkout(Workout workout) {
    final workoutProvider = context.read<WorkoutProvider>();
    workoutProvider.setWorkout(workout);

    // Navigate to timer tab
    widget.onNavigateToTimer?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Workouts'),
        actions: [
          IconButton(
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
            child: WorkoutCard(
              workout: workout,
              onTap: () => _startWorkout(workout),
              onFavoriteToggle: () => _toggleFavorite(workout),
              onDelete: () => _deleteWorkout(workout),
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
              decoration: BoxDecoration(
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
            Text(
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
            Text(
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
