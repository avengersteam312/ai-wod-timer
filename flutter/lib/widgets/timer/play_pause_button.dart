import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/haptics_service.dart';

/// Customizable play/pause button with animation
class PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final Gradient? gradient;
  final bool showShadow;
  final IconData playIcon;
  final IconData pauseIcon;

  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.size = 72,
    this.backgroundColor,
    this.iconColor,
    this.gradient,
    this.showShadow = true,
    this.playIcon = Icons.play_arrow,
    this.pauseIcon = Icons.pause,
  });

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    HapticsService.instance.actionTriggered();
    widget.onPressed();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ??
        (widget.backgroundColor == null ? AppColors.primaryGradient : null);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                gradient: effectiveGradient,
                color: widget.backgroundColor,
                shape: BoxShape.circle,
                boxShadow: widget.showShadow
                    ? [
                        BoxShadow(
                          color: (widget.backgroundColor ?? AppColors.primary)
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.isPlaying ? widget.pauseIcon : widget.playIcon,
                color: widget.iconColor ?? AppColors.textPrimary,
                size: widget.size * 0.45,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Circular control button (reset, stop, skip, etc.)
class CircularControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? borderColor;
  final bool disabled;
  final bool showBorder;

  const CircularControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.backgroundColor,
    this.iconColor,
    this.borderColor,
    this.disabled = false,
    this.showBorder = false,
  });

  @override
  State<CircularControlButton> createState() => _CircularControlButtonState();
}

class _CircularControlButtonState extends State<CircularControlButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.disabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.disabled
          ? null
          : (_) {
              setState(() => _isPressed = false);
              HapticsService.instance.buttonTap();
              widget.onPressed();
            },
      onTapCancel: widget.disabled
          ? null
          : () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: widget.disabled ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? AppColors.inputBackground,
              shape: BoxShape.circle,
              border: widget.showBorder
                  ? Border.all(
                      color: widget.borderColor ?? AppColors.border,
                      width: 1,
                    )
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: widget.iconColor ?? AppColors.textSecondary,
              size: widget.size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Flexible timer controls row that accepts custom buttons
class FlexibleTimerControls extends StatelessWidget {
  final Widget? leftButton;
  final Widget centerButton;
  final Widget? rightButton;
  final double spacing;
  final double placeholderSize;

  const FlexibleTimerControls({
    super.key,
    this.leftButton,
    required this.centerButton,
    this.rightButton,
    this.spacing = 24,
    this.placeholderSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leftButton != null) leftButton! else SizedBox(width: placeholderSize),
        SizedBox(width: spacing),
        centerButton,
        SizedBox(width: spacing),
        if (rightButton != null) rightButton! else SizedBox(width: placeholderSize),
      ],
    );
  }
}
