import 'package:flutter/material.dart';
import '../ui_test_keys.dart';
import '../theme/app_theme.dart';

/// Hamburger menu button for opening app drawer.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: UiTestKeys.authButton,
      icon: const Icon(
        Icons.menu,
        color: AppColors.textPrimary,
        size: 24,
      ),
      onPressed: () {
        Scaffold.of(context).openDrawer();
      },
    );
  }
}

/// Backwards compatibility alias
@Deprecated('Use MenuButton instead')
typedef AuthButton = MenuButton;
