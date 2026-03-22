import 'package:flutter/material.dart';

/// Zoom control widget like iPhone camera (0.5x, 1x, 2x buttons)
class ZoomControl extends StatelessWidget {
  final double currentZoom;
  final List<double> presets;
  final ValueChanged<double> onZoomChanged;
  final bool enabled;

  const ZoomControl({
    super.key,
    required this.currentZoom,
    required this.presets,
    required this.onZoomChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (presets.length < 2) {
      // Single zoom level, no control needed
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: presets.map((zoom) {
          final isSelected = _isZoomSelected(zoom);
          return _ZoomButton(
            zoom: zoom,
            isSelected: isSelected,
            enabled: enabled,
            onTap: () => onZoomChanged(zoom),
          );
        }).toList(),
      ),
    );
  }

  bool _isZoomSelected(double zoom) {
    // Consider zoom selected if within 0.1 of current
    return (currentZoom - zoom).abs() < 0.1;
  }
}

class _ZoomButton extends StatelessWidget {
  final double zoom;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.zoom,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = _formatZoom(zoom);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.yellow
                  : Colors.white.withValues(alpha: enabled ? 0.9 : 0.4),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  String _formatZoom(double zoom) {
    if (zoom == 0.5) return '.5';
    if (zoom == 1.0) return '1x';
    if (zoom == 1.5) return '1.5';
    if (zoom == 2.0) return '2x';
    // For other values, show one decimal
    return '${zoom.toStringAsFixed(1)}x';
  }
}
