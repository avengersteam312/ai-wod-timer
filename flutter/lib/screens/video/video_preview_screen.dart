import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_theme.dart';
import '../../services/video_service.dart';
import '../../utils/snackbar_utils.dart';

/// Video preview and export screen
class VideoPreviewScreen extends StatefulWidget {
  final String videoPath;
  final String? rawVideoPath;

  const VideoPreviewScreen({
    super.key,
    required this.videoPath,
    this.rawVideoPath,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isSaving = false;
  bool _isSharing = false;
  double? _fileSizeMB;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _loadFileSize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));

    await _controller.initialize();
    await _controller.setLooping(true);
    // Don't autoplay - let user tap to play

    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _loadFileSize() async {
    final size = await VideoService().getVideoSizeMB(widget.videoPath);
    if (mounted) {
      setState(() {
        _fileSizeMB = size;
      });
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);

    final success = await VideoService().saveToGallery(widget.videoPath);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        AppSnackBar.showSuccess(context, 'Video saved to gallery');
      } else {
        AppSnackBar.showError(context, 'Failed to save video');
      }
    }
  }

  Future<void> _shareVideo() async {
    setState(() => _isSharing = true);

    // Get screen size for share position (required on iPad)
    final box = context.findRenderObject() as RenderBox?;
    final sharePosition = box != null
        ? Rect.fromLTWH(0, 0, box.size.width, box.size.height / 2)
        : null;

    await VideoService().shareVideo(
      widget.videoPath,
      sharePositionOrigin: sharePosition,
    );

    setState(() => _isSharing = false);
  }

  void _discardAndClose() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Discard Video?'),
        content: const Text('This video will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await VideoService().deleteVideo(widget.videoPath);
              if (widget.rawVideoPath != null) {
                await VideoService().deleteVideo(widget.rawVideoPath!);
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _discardAndClose,
        ),
        title: const Text('Preview'),
        actions: [
          if (_fileSizeMB != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  '${_fileSizeMB!.toStringAsFixed(1)} MB',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Video preview
          Expanded(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                color: Colors.black,
                child: _isInitialized
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          // Video
                          Center(
                            child: AspectRatio(
                              aspectRatio: _controller.value.aspectRatio,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                          // Play/pause overlay
                          if (!_controller.value.isPlaying)
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                        ],
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
              ),
            ),
          ),

          // Video progress bar
          if (_isInitialized)
            VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppColors.primary,
                bufferedColor: AppColors.primary.withValues(alpha: 0.3),
                backgroundColor: AppColors.inputBackground,
              ),
            ),

          // Action buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Save to gallery
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.download,
                      label: 'Save',
                      isLoading: _isSaving,
                      onTap: _saveToGallery,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Share
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.share,
                      label: 'Share',
                      isLoading: _isSharing,
                      isPrimary: true,
                      onTap: _shareVideo,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isLoading = false,
    this.isPrimary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPrimary ? Colors.white : AppColors.primary,
                ),
              )
            else
              Icon(
                icon,
                color: isPrimary ? Colors.white : AppColors.textPrimary,
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.button.copyWith(
                color: isPrimary ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
