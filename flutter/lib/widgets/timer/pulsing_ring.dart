import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Pulsing ring animation to indicate tappable area
class PulsingRing extends StatefulWidget {
  final Widget child;
  final double size;
  final bool enabled;
  final Color color;

  const PulsingRing({
    super.key,
    required this.child,
    required this.size,
    this.enabled = true,
    this.color = AppColors.primary,
  });

  @override
  State<PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<PulsingRing>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _opacityAnimations;

  static const int _waveCount = 3;
  static const int _waveDuration = 2000; // ms
  static const int _waveDelay = 600; // ms between waves

  @override
  void initState() {
    super.initState();
    _initAnimations();
    if (widget.enabled) {
      _startAnimations();
    }
  }

  void _initAnimations() {
    _controllers = List.generate(_waveCount, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: _waveDuration),
        vsync: this,
      );
    });

    _scaleAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 1.0, end: 1.25).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();

    _opacityAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.6, end: 0.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();
  }

  void _startAnimations() {
    for (int i = 0; i < _waveCount; i++) {
      Future.delayed(Duration(milliseconds: i * _waveDelay), () {
        if (mounted && widget.enabled) {
          _controllers[i].repeat();
        }
      });
    }
  }

  void _stopAnimations() {
    for (var controller in _controllers) {
      controller.stop();
      controller.reset();
    }
  }

  @override
  void didUpdateWidget(PulsingRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controllers[0].isAnimating) {
      _startAnimations();
    } else if (!widget.enabled && _controllers[0].isAnimating) {
      _stopAnimations();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size + 80,
      height: widget.size + 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Multiple pulsing rings (starting outside the progress ring)
          if (widget.enabled)
            ...List.generate(_waveCount, (index) {
              return AnimatedBuilder(
                animation: _controllers[index],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimations[index].value,
                    child: Container(
                      width: widget.size + 20,
                      height: widget.size + 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color.withValues(
                            alpha: _opacityAnimations[index].value,
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          // Main child
          widget.child,
        ],
      ),
    );
  }
}
