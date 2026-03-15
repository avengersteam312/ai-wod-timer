import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/workout_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../ui_test_keys.dart';
import '../../utils/snackbar_utils.dart';
import '../../widgets/auth_button.dart';
import '../../widgets/session_card.dart';

class HistoryScreen extends StatefulWidget {
  final bool isVisible;
  final SyncService? syncService;
  final Future<List<WorkoutSession>> Function(String userId)? loadSessions;
  final Future<void> Function(String sessionId)? deleteSession;

  const HistoryScreen({
    super.key,
    this.isVisible = false,
    this.syncService,
    this.loadSessions,
    this.deleteSession,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = false;
  List<WorkoutSession> _sessions = [];
  String? _error;

  SyncService get _syncService => widget.syncService ?? SyncService();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh when tab becomes visible
    if (widget.isVisible && !oldWidget.isVisible) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id ?? 'anonymous';

      final sessions = await (widget.loadSessions?.call(userId) ??
          _syncService.getSessions(userId));

      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load history';
        _isLoading = false;
      });
    }
  }

  Map<String, List<WorkoutSession>> _groupSessionsByDate() {
    final grouped = <String, List<WorkoutSession>>{};

    for (final session in _sessions) {
      final date = _getDateKey(session.startedAt);
      grouped.putIfAbsent(date, () => []).add(session);
    }

    return grouped;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(sessionDate).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMMM d, y').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: const [
          AuthButton(),
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

    if (_sessions.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // Stats summary
          SliverToBoxAdapter(
            child: _buildStatsSummary(),
          ),

          // Sessions grouped by date
          ..._buildGroupedSessions(),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    final completedSessions =
        _sessions.where((s) => s.status == SessionStatus.completed).toList();
    final totalMinutes = completedSessions.fold<int>(
          0,
          (sum, s) => sum + (s.durationSeconds ?? 0),
        ) ~/
        60;

    // Get unique workout days this week
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekSessions = _sessions.where((s) {
      return s.startedAt.isAfter(weekStart);
    }).toList();

    final uniqueDays = <int>{};
    for (final session in thisWeekSessions) {
      uniqueDays.add(session.startedAt.day);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: SessionStatCard(
              label: 'Timers',
              value: '${completedSessions.length}',
              icon: Icons.fitness_center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SessionStatCard(
              label: 'Total Time',
              value: '${totalMinutes}m',
              icon: Icons.timer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SessionStatCard(
              label: 'This Week',
              value: '${uniqueDays.length}',
              icon: Icons.calendar_today,
              iconColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedSessions() {
    final grouped = _groupSessionsByDate();
    final widgets = <Widget>[];

    grouped.forEach((date, sessions) {
      // Date header
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              date,
              style: AppTextStyles.label,
            ),
          ),
        ),
      );

      // Sessions for this date
      widgets.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final session = sessions[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Dismissible(
                  key: UiTestKeys.historySession(session.id),
                  direction: DismissDirection.endToStart,
                  dismissThresholds: const {DismissDirection.endToStart: 0.5},
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (direction) {
                    _deleteSession(session);
                  },
                  child: SessionCard(
                    session: session,
                    onTap: () => _showSessionDetails(session),
                  ),
                ),
              );
            },
            childCount: sessions.length,
          ),
        ),
      );
    });

    return widgets;
  }

  Future<void> _deleteSession(WorkoutSession session) async {
    try {
      await (widget.deleteSession?.call(session.id) ??
          _syncService.deleteSession(session.id));
      setState(() {
        _sessions.removeWhere((s) => s.id == session.id);
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to delete session');
      }
    }
  }

  void _showSessionDetails(WorkoutSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SessionDetailsSheet(session: session),
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
                Icons.history,
                size: 40,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No History',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 8),
            Text(
              'Your completed sessions will appear here.',
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
              key: UiTestKeys.historyRetryButton,
              onPressed: _loadHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionDetailsSheet extends StatelessWidget {
  final WorkoutSession session;

  const _SessionDetailsSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Workout name and status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        session.workoutName,
                        style: AppTextStyles.h2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(),
                  ],
                ),
                const SizedBox(height: 24),

                // Stats grid
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        label: 'Duration',
                        value: session.formattedDuration,
                        icon: Icons.timer,
                      ),
                    ),
                    // Only show work time if workout was completed and has rest intervals
                    if (session.status == SessionStatus.completed &&
                        session.hasRestIntervals &&
                        session.formattedWorkTime != null) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatItem(
                          label: 'Work',
                          value: session.formattedWorkTime!,
                          icon: Icons.fitness_center,
                        ),
                      ),
                    ],
                    if (session.roundsCompleted != null) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatItem(
                          label: 'Rounds',
                          value: '${session.roundsCompleted}',
                          icon: Icons.repeat,
                        ),
                      ),
                    ] else if (!(session.hasRestIntervals &&
                        session.formattedWorkTime != null)) ...[
                      const SizedBox(width: 16),
                      const Spacer(),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        label: 'Date',
                        value: DateFormat('MMM d, y').format(session.startedAt),
                        icon: Icons.calendar_today,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatItem(
                        label: 'Time',
                        value: DateFormat('h:mm a').format(session.startedAt),
                        icon: Icons.access_time,
                      ),
                    ),
                  ],
                ),

                // Notes
                if (session.notes != null && session.notes!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Notes',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      session.notes!,
                      style: AppTextStyles.body,
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label;
    IconData icon;

    switch (session.status) {
      case SessionStatus.completed:
        color = AppColors.success;
        label = 'Completed';
        icon = Icons.check_circle;
        break;
      case SessionStatus.abandoned:
        color = AppColors.warning;
        label = 'Abandoned';
        icon = Icons.cancel;
        break;
      case SessionStatus.inProgress:
        color = AppColors.primary;
        label = 'In Progress';
        icon = Icons.play_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.buttonSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.h4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
