import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../ui_test_keys.dart';
import '../providers/workout_provider.dart';
import '../screens/auth/login_screen.dart';
import '../theme/app_theme.dart';

/// Reusable auth button for AppBar actions.
/// Shows profile menu when authenticated, sign in button when not.
/// Hidden when authRequired is false.
class AuthButton extends StatelessWidget {
  const AuthButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Hide auth button if auth is not enabled
    if (!AppConfig.authEnabled) {
      return const SizedBox.shrink();
    }

    final auth = context.watch<AuthProvider>();

    if (auth.isAuthenticated) {
      return PopupMenuButton<String>(
        key: UiTestKeys.authButton,
        icon: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        onSelected: (value) async {
          if (value == 'signout') {
            // Clear any workout errors before signing out
            context.read<WorkoutProvider>().clearParseError();
            await auth.signOut();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              auth.user?.email ?? '',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'signout',
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
    } else {
      return IconButton(
        key: UiTestKeys.authButton,
        icon: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
      );
    }
  }
}
