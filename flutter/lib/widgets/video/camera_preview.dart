import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../theme/app_theme.dart';

/// Camera preview widget
class CameraPreview extends StatelessWidget {
  final CameraController? controller;
  final bool isInitialized;
  final bool isFrontCamera;
  final bool isFlashOn;
  final VoidCallback? onFlipCamera;
  final VoidCallback? onToggleFlash;

  const CameraPreview({
    super.key,
    required this.controller,
    required this.isInitialized,
    this.isFrontCamera = true,
    this.isFlashOn = false,
    this.onFlipCamera,
    this.onToggleFlash,
  });

  @override
  Widget build(BuildContext context) {
    // Check initialization state and ensure controller isn't disposed
    if (!isInitialized || controller == null) {
      return Container(
        color: AppColors.background,
      );
    }

    // Check controller's own state (including if it's been disposed)
    try {
      if (!controller!.value.isInitialized) {
        return Container(
          color: AppColors.background,
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller!.value.previewSize?.height ?? 1,
            height: controller!.value.previewSize?.width ?? 1,
            child: controller!.buildPreview(),
          ),
        ),
      );
    } catch (e) {
      // Controller was disposed, show background
      return Container(
        color: AppColors.background,
      );
    }
  }
}
