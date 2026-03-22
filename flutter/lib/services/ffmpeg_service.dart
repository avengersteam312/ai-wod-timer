import 'package:flutter/foundation.dart';
import '../providers/video_provider.dart';

// FFmpeg Kit is disabled for simulator builds
// Uncomment these imports when ffmpeg_kit_flutter_new is enabled in pubspec.yaml:
// import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
// import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Callback for FFmpeg processing progress (0.0 - 1.0)
typedef FFmpegProgressCallback = void Function(double progress);

/// Service for video processing with FFmpeg
/// Bakes timer overlay, watermark, and date stamp into video
///
/// NOTE: This is a stub implementation when FFmpeg is disabled.
/// Enable ffmpeg_kit_flutter_new in pubspec.yaml for full functionality.
class FFmpegService {
  static final FFmpegService _instance = FFmpegService._internal();
  factory FFmpegService() => _instance;
  FFmpegService._internal();

  /// Whether FFmpeg is available (disabled for simulator builds)
  static const bool isAvailable = false; // Set to true when FFmpeg is enabled

  /// Process video with timer overlay, watermark, and date stamp
  /// Returns null when FFmpeg is not available (simulator builds)
  Future<String?> processVideoWithOverlay({
    required String inputPath,
    required List<TimerFrame> frames,
    required DateTime recordingDate,
    FFmpegProgressCallback? onProgress,
  }) async {
    if (!isAvailable) {
      debugPrint('[FFmpegService] FFmpeg not available (simulator build)');
      return null;
    }

    // Full implementation is commented out - enable when FFmpeg is available
    return null;
  }

  /// Get estimated processing time based on video duration
  Duration estimateProcessingTime(Duration videoDuration) {
    return Duration(seconds: (videoDuration.inSeconds * 3).clamp(5, 120));
  }

  /// Cancel any running FFmpeg operation
  Future<void> cancel() async {
    debugPrint('[FFmpegService] Cancel called (no-op in stub)');
  }
}

// ============================================================================
// FULL FFMPEG IMPLEMENTATION - Uncomment when ffmpeg_kit_flutter_new is enabled
// ============================================================================
/*
import 'package:flutter/services.dart' show rootBundle;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class FFmpegServiceFull {
  static final FFmpegServiceFull _instance = FFmpegServiceFull._internal();
  factory FFmpegServiceFull() => _instance;
  FFmpegServiceFull._internal();

  String? _fontPath;

  Future<void> _initializeAssets() async {
    if (_fontPath != null) return;

    final tempDir = await getTemporaryDirectory();
    final fontData = await rootBundle.load('assets/fonts/RobotoMono-Bold.ttf');
    final fontFile = File('${tempDir.path}/RobotoMono-Bold.ttf');
    await fontFile.writeAsBytes(fontData.buffer.asUint8List());
    _fontPath = fontFile.path;
  }

  Future<({int width, int height})> _getVideoDimensions(String videoPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final info = session.getMediaInformation();
      if (info != null) {
        final streams = info.getStreams();
        for (final stream in streams) {
          final width = stream.getWidth();
          final height = stream.getHeight();
          if (width != null && height != null) {
            return (width: width, height: height);
          }
        }
      }
    } catch (e) {
      debugPrint('[FFmpegService] Failed to get dimensions: $e');
    }
    return (width: 1080, height: 1920);
  }

  Future<String?> processVideoWithOverlay({
    required String inputPath,
    required List<TimerFrame> frames,
    required DateTime recordingDate,
    FFmpegProgressCallback? onProgress,
  }) async {
    try {
      await _initializeAssets();
      final dimensions = await _getVideoDimensions(inputPath);
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/wod_processed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final assContent = _generateASS(frames, dimensions.width, dimensions.height);
      final assPath = '${tempDir.path}/timer_overlay.ass';
      await File(assPath).writeAsString(assContent);

      final command = _buildFFmpegCommand(
        inputPath: inputPath,
        outputPath: outputPath,
        assPath: assPath,
        recordingDate: recordingDate,
        videoWidth: dimensions.width,
        videoHeight: dimensions.height,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      }
      return null;
    } catch (e) {
      debugPrint('[FFmpegService] Error: $e');
      return null;
    }
  }

  String _generateASS(List<TimerFrame> frames, int videoWidth, int videoHeight) {
    // ASS subtitle generation code...
    return '';
  }

  String _buildFFmpegCommand({
    required String inputPath,
    required String outputPath,
    required String assPath,
    required DateTime recordingDate,
    required int videoWidth,
    required int videoHeight,
  }) {
    final escapedAssPath = assPath.replaceAll(':', '\\:');
    return '-y -i "$inputPath" -filter_complex "[0:v]ass=$escapedAssPath[v]" '
        '-map "[v]" -map "0:a?" -c:v libx264 -c:a copy -preset fast -crf 23 "$outputPath"';
  }

  Future<void> cancel() async {
    await FFmpegKit.cancel();
  }
}
*/
