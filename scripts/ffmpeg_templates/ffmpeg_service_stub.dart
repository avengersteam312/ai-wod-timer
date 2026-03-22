import 'package:flutter/foundation.dart';

import '../providers/video_provider.dart';

/// Callback for FFmpeg processing progress (0.0 - 1.0)
typedef FFmpegProgressCallback = void Function(double progress);

/// Stub implementation of FFmpegService when FFmpeg is disabled.
/// All methods return null/no-op.
///
/// This file is used when FFmpeg is disabled for simulator builds.
/// Toggle with: ./scripts/toggle_ffmpeg.sh enable|disable
class FFmpegService {
  static final FFmpegService _instance = FFmpegService._internal();
  factory FFmpegService() => _instance;
  FFmpegService._internal();

  /// FFmpeg is not available in stub mode
  static const bool isAvailable = false;

  /// Process video - returns null (FFmpeg disabled)
  Future<String?> processVideoWithOverlay({
    required String inputPath,
    required List<TimerFrame> frames,
    required DateTime recordingDate,
    FFmpegProgressCallback? onProgress,
  }) async {
    debugPrint('[FFmpegService] FFmpeg not available (stub mode)');
    return null;
  }

  /// Get estimated processing time based on video duration
  Duration estimateProcessingTime(Duration videoDuration) {
    return Duration(seconds: (videoDuration.inSeconds * 3).clamp(5, 120));
  }

  /// Cancel - no-op in stub mode
  Future<void> cancel() async {
    debugPrint('[FFmpegService] Cancel called (stub mode)');
  }
}
