import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable app bar actions for timer screens
/// Includes save, sound toggle, and profile button
class TimerAppBarActions extends StatelessWidget {
  final bool isSaved;
  final bool isMuted;
  final bool showSave;
  final bool showSound;
  final bool showProfile;
  final VoidCallback? onSave;
  final VoidCallback? onToggleSound;
  final Widget? profileButton;

  const TimerAppBarActions({
    super.key,
    this.isSaved = false,
    this.isMuted = false,
    this.showSave = true,
    this.showSound = true,
    this.showProfile = true,
    this.onSave,
    this.onToggleSound,
    this.profileButton,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSave && !isSaved)
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save workout',
            onPressed: onSave,
          ),
        if (showSave && isSaved)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.check_circle,
              color: AppColors.success,
            ),
          ),
        if (showSound)
          IconButton(
            icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
            tooltip: isMuted ? 'Unmute' : 'Mute',
            onPressed: onToggleSound,
          ),
        if (showProfile && profileButton != null) profileButton!,
      ],
    );
  }
}

/// Profile avatar button with dropdown menu
class ProfileAvatarButton extends StatelessWidget {
  final String? email;
  final VoidCallback? onLogout;
  final List<PopupMenuEntry<String>>? additionalItems;

  const ProfileAvatarButton({
    super.key,
    this.email,
    this.onLogout,
    this.additionalItems,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
        child: Text(
          email?.substring(0, 1).toUpperCase() ?? '?',
          style: AppTextStyles.buttonSmall.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
      onSelected: (value) {
        if (value == 'logout') {
          onLogout?.call();
        }
      },
      itemBuilder: (context) => [
        if (email != null)
          PopupMenuItem(
            enabled: false,
            child: Text(
              email!,
              style: AppTextStyles.bodySmall,
            ),
          ),
        if (email != null) const PopupMenuDivider(),
        if (additionalItems != null) ...additionalItems!,
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 8),
              Text('Sign Out'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Offline indicator badge
class OfflineIndicator extends StatelessWidget {
  final bool isOffline;

  const OfflineIndicator({
    super.key,
    required this.isOffline,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off,
            size: 14,
            color: AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            'Offline',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
