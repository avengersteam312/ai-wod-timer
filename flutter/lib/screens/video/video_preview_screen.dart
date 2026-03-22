import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../theme/app_theme.dart';
import '../../services/video_service.dart';
import '../../providers/video_provider.dart';
import '../../utils/snackbar_utils.dart';

/// Video preview and export screen
/// Processes raw video with FFmpeg to bake in timer overlay, watermark, and date
class VideoPreviewScreen extends StatefulWidget {
  final String videoPath;
  final String? rawVideoPath;
  final List<TimerFrame>? timerFrames;
  final DateTime? recordingDate;

  const VideoPreviewScreen({
    super.key,
    required this.videoPath,
    this.rawVideoPath,
    this.timerFrames,
    this.recordingDate,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = true;
  bool _processingFailed = false;
  bool _isSaving = false;
  bool _isSharing = false;
  double? _fileSizeMB;
  String? _processedVideoPath;

  @override
  void initState() {
    super.initState();
    _processAndInitialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _processAndInitialize() async {
    // Process video with FFmpeg if we have timer frames
    if (widget.timerFrames != null && widget.timerFrames!.isNotEmpty) {
      setState(() {
        _isProcessing = true;
        _processingFailed = false;
      });

      final processedPath = await VideoService().processVideo(
        inputPath: widget.videoPath,
        timerFrames: widget.timerFrames,
        recordingDate: widget.recordingDate,
      );

      if (processedPath != null) {
        _processedVideoPath = processedPath;
      } else {
        // FFmpeg failed, use raw video
        _processedVideoPath = widget.videoPath;
        _processingFailed = true;
      }
    } else {
      // No timer frames, use raw video directly
      _processedVideoPath = widget.videoPath;
    }

    setState(() {
      _isProcessing = false;
    });

    await _initializeVideo();
    await _loadFileSize();
  }

  Future<void> _initializeVideo() async {
    if (_processedVideoPath == null) return;

    _controller = VideoPlayerController.file(File(_processedVideoPath!));

    await _controller!.initialize();
    await _controller!.setLooping(true);
    // Don't autoplay - let user tap to play

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _loadFileSize() async {
    if (_processedVideoPath == null) return;

    final size = await VideoService().getVideoSizeMB(_processedVideoPath!);
    if (mounted) {
      setState(() {
        _fileSizeMB = size;
      });
    }
  }

  Future<void> _saveToGallery() async {
    final videoPath = _processedVideoPath;
    if (videoPath == null) return;

    setState(() => _isSaving = true);

    final success = await VideoService().saveToGallery(videoPath);

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
    final videoPath = _processedVideoPath;
    if (videoPath == null) return;

    setState(() => _isSharing = true);

    // Get screen size for share position (required on iPad)
    final box = context.findRenderObject() as RenderBox?;
    final sharePosition = box != null
        ? Rect.fromLTWH(0, 0, box.size.width, box.size.height / 2)
        : null;

    await VideoService().shareVideo(
      videoPath,
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
              // Delete processed video if different from raw
              if (_processedVideoPath != null &&
                  _processedVideoPath != widget.videoPath) {
                await VideoService().deleteVideo(_processedVideoPath!);
              }
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
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isProcessing ? null : _discardAndClose,
        ),
        title: Text(_isProcessing ? 'Processing...' : 'Preview'),
        actions: [
          if (_processingFailed)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Tooltip(
                  message: 'Overlay processing failed. Video saved without overlays.',
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                ),
              ),
            ),
          if (_fileSizeMB != null && !_isProcessing)
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
          // Video preview or processing indicator
          Expanded(
            child: GestureDetector(
              onTap: _isProcessing ? null : _togglePlayPause,
              child: Container(
                color: Colors.black,
                child: _isProcessing
                    ? _buildProcessingIndicator()
                    : _isInitialized && controller != null
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              // Video
                              Center(
                                child: AspectRatio(
                                  aspectRatio: controller.value.aspectRatio,
                                  child: VideoPlayer(controller),
                                ),
                              ),
                              // Play/pause overlay
                              if (!controller.value.isPlaying)
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
          if (_isInitialized && controller != null)
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppColors.primary,
                bufferedColor: AppColors.primary.withValues(alpha: 0.3),
                backgroundColor: AppColors.inputBackground,
              ),
            ),

          // Action buttons (disabled during processing)
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
                      isDisabled: _isProcessing,
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
                      isDisabled: _isProcessing,
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

  Widget _buildProcessingIndicator() {
    return const Center(
      child: SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

/// Action button widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final bool isDisabled;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isLoading = false,
    this.isDisabled = false,
    this.isPrimary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectivelyDisabled = isLoading || isDisabled;
    final opacity = effectivelyDisabled ? 0.5 : 1.0;

    return GestureDetector(
      onTap: effectivelyDisabled ? null : onTap,
      child: Opacity(
        opacity: opacity,
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
      ),
    );
  }
}
