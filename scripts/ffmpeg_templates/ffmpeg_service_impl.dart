import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/video_provider.dart';

/// Callback for FFmpeg processing progress (0.0 - 1.0)
typedef FFmpegProgressCallback = void Function(double progress);

/// Service for video processing with FFmpeg
/// Bakes timer overlay, watermark, and date stamp into video
///
/// Toggle with: ./scripts/toggle_ffmpeg.sh enable|disable
class FFmpegService {
  static final FFmpegService _instance = FFmpegService._internal();
  factory FFmpegService() => _instance;
  FFmpegService._internal();

  /// FFmpeg is available (impl file is active)
  static const bool isAvailable = true;

  String? _fontPath;

  /// Initialize assets (copy font to temp directory)
  Future<void> _initializeAssets() async {
    if (_fontPath != null) return;

    final tempDir = await getTemporaryDirectory();

    // Copy font to temp directory
    final fontData = await rootBundle.load('assets/fonts/RobotoMono-Bold.ttf');
    final fontFile = File('${tempDir.path}/RobotoMono-Bold.ttf');
    await fontFile.writeAsBytes(fontData.buffer.asUint8List());
    _fontPath = fontFile.path;

    debugPrint('[FFmpegService] Assets initialized: font=$_fontPath');
  }

  /// Get video dimensions using ffprobe
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
            debugPrint('[FFmpegService] Video dimensions: ${width}x$height');
            return (width: width, height: height);
          }
        }
      }
    } catch (e) {
      debugPrint('[FFmpegService] Failed to get video dimensions: $e');
    }

    // Default to common iPhone portrait resolution
    debugPrint('[FFmpegService] Using default dimensions: 1080x1920');
    return (width: 1080, height: 1920);
  }

  /// Process video with timer overlay, watermark, and date stamp
  Future<String?> processVideoWithOverlay({
    required String inputPath,
    required List<TimerFrame> frames,
    required DateTime recordingDate,
    FFmpegProgressCallback? onProgress,
  }) async {
    try {
      await _initializeAssets();

      // Get video dimensions for responsive sizing
      final dimensions = await _getVideoDimensions(inputPath);

      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/wod_processed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Generate ASS subtitle file for timer overlay (supports per-line styling)
      final assContent = _generateASS(frames, dimensions.width, dimensions.height);
      final assPath = '${tempDir.path}/timer_overlay.ass';
      await File(assPath).writeAsString(assContent);
      debugPrint('[FFmpegService] ASS file created: $assPath');
      debugPrint('[FFmpegService] ASS content:\n$assContent');

      // Build FFmpeg command
      final command = _buildFFmpegCommand(
        inputPath: inputPath,
        outputPath: outputPath,
        assPath: assPath,
        recordingDate: recordingDate,
        videoWidth: dimensions.width,
        videoHeight: dimensions.height,
      );

      debugPrint('[FFmpegService] Executing: ffmpeg $command');

      // Execute FFmpeg
      final session = await FFmpegKit.execute(command);

      // Check result
      final returnCode = await session.getReturnCode();
      final logs = await session.getAllLogsAsString();

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('[FFmpegService] Video processed successfully: $outputPath');
        return outputPath;
      } else {
        debugPrint('[FFmpegService] FFmpeg failed with code: $returnCode');
        debugPrint('[FFmpegService] FFmpeg logs: $logs');
        return null;
      }
    } catch (e, stack) {
      debugPrint('[FFmpegService] Error processing video: $e');
      debugPrint('[FFmpegService] Stack: $stack');
      return null;
    }
  }

  /// Generate ASS subtitle file content from timer frames
  /// ASS format supports different styles for round indicator vs timer
  String _generateASS(List<TimerFrame> frames, int videoWidth, int videoHeight) {
    if (frames.isEmpty) return '';

    // Calculate font sizes based on video dimensions (matching Flutter overlay ratios)
    // Flutter: timer=32px, round=12px on ~400px logical width
    final shortDimension = videoWidth < videoHeight ? videoWidth : videoHeight;
    final timerFontSize = (shortDimension * 0.10).round().clamp(40, 120); // ~10% of width
    final roundFontSize = (timerFontSize * 0.4).round().clamp(16, 48); // 40% of timer size

    // Margins
    final marginL = (videoWidth * 0.025).round().clamp(10, 50);
    final marginV = (videoHeight * 0.04).round().clamp(20, 100);

    debugPrint('[FFmpegService] ASS sizing: timerFont=$timerFontSize, roundFont=$roundFontSize, marginL=$marginL, marginV=$marginV');

    final buffer = StringBuffer();

    // ASS header with styles
    buffer.writeln('[Script Info]');
    buffer.writeln('ScriptType: v4.00+');
    buffer.writeln('PlayResX: $videoWidth');
    buffer.writeln('PlayResY: $videoHeight');
    buffer.writeln('');
    buffer.writeln('[V4+ Styles]');
    buffer.writeln('Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
    // Letter spacing relative to font size (for tabular-like appearance)
    final timerSpacing = (timerFontSize * 0.05).round().clamp(2, 6);
    final roundSpacing = (roundFontSize * 0.03).round().clamp(1, 3);

    // Timer style: white, bold, larger, no outline/shadow, with letter spacing (top-left, Alignment=7)
    buffer.writeln('Style: Timer,Helvetica,$timerFontSize,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,1,0,0,0,100,100,$timerSpacing,0,1,0,0,7,$marginL,$marginL,$marginV,1');
    // Round indicator style: white70 (4D = ~30% transparent), smaller, no outline/shadow (top-left, Alignment=7)
    buffer.writeln('Style: Round,Helvetica,$roundFontSize,&H4DFFFFFF,&H4DFFFFFF,&H00000000,&H00000000,0,0,0,0,100,100,$roundSpacing,0,1,0,0,7,$marginL,$marginL,$marginV,1');
    // Recording time style: white, smaller, top-right (Alignment=9)
    final recFontSize = (roundFontSize * 0.9).round().clamp(12, 36);
    buffer.writeln('Style: RecTime,Helvetica,$recFontSize,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,1,0,0,0,100,100,$roundSpacing,0,1,0,0,9,$marginL,$marginL,$marginV,1');
    buffer.writeln('');
    buffer.writeln('[Events]');
    buffer.writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    for (int i = 0; i < frames.length; i++) {
      final frame = frames[i];
      final nextFrame = i + 1 < frames.length ? frames[i + 1] : null;

      // Ensure first frame starts at 0
      final startTime = i == 0 ? Duration.zero : frame.timestamp;
      final start = _formatASSTime(startTime);
      final end = _formatASSTime(
        nextFrame?.timestamp ?? frame.timestamp + const Duration(seconds: 1),
      );

      // Add round indicator line if available (smaller, semi-transparent)
      if (frame.roundIndicator != null) {
        final prefix = frame.isRest ? 'Rest' : 'Round';
        buffer.writeln('Dialogue: 0,$start,$end,Round,,0,0,0,,$prefix ${frame.roundIndicator}');
      }

      // Add timer line (larger, white) - offset down if round indicator present
      final timerMarginV = frame.roundIndicator != null ? marginV + roundFontSize + 4 : marginV;
      buffer.writeln('Dialogue: 0,$start,$end,Timer,,0,0,$timerMarginV,,${frame.displayTime}');

      // Add recording time with red dot (top-right)
      // ASS inline color: {\c&HBBGGRR&} - red is &H0000FF&
      if (frame.recordingTime != null) {
        buffer.writeln('Dialogue: 0,$start,$end,RecTime,,0,0,0,,{\\c&H0000FF&}●{\\c&HFFFFFF&} ${frame.recordingTime}');
      }
    }

    return buffer.toString();
  }

  /// Format duration as ASS timestamp (H:MM:SS.CC - centiseconds)
  String _formatASSTime(Duration d) {
    final hours = d.inHours;
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final centis = ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds.$centis';
  }

  /// Build FFmpeg command for video processing
  String _buildFFmpegCommand({
    required String inputPath,
    required String outputPath,
    required String assPath,
    required DateTime recordingDate,
    required int videoWidth,
    required int videoHeight,
  }) {
    final escapedAssPath = _escapeFilterValue(assPath);

    // Use ASS subtitles (styling is embedded in the ASS file)
    // ASS file contains two styles: Timer (large white) and Round (small white70)
    final filterComplex = '[0:v]ass=$escapedAssPath[v]';

    return '-y '
        '-i "$inputPath" '
        '-filter_complex "$filterComplex" '
        '-map "[v]" '
        '-map "0:a?" '
        '-c:v libx264 '
        '-c:a copy '
        '-preset fast '
        '-crf 23 '
        '"$outputPath"';
  }

  /// Escape special characters in file paths and values for FFmpeg filter syntax
  String _escapeFilterValue(String value) {
    // Escape special characters for FFmpeg filter syntax:
    // - backslashes, colons, single quotes, brackets
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll(':', '\\:')
        .replaceAll("'", "\\'")
        .replaceAll('[', '\\[')
        .replaceAll(']', '\\]');
  }

  /// Get estimated processing time based on video duration
  Duration estimateProcessingTime(Duration videoDuration) {
    // Rough estimate: 2-5 seconds per second of video on mobile
    // This varies widely based on device performance
    return Duration(seconds: (videoDuration.inSeconds * 3).clamp(5, 120));
  }

  /// Cancel any running FFmpeg operation
  Future<void> cancel() async {
    await FFmpegKit.cancel();
    debugPrint('[FFmpegService] FFmpeg operation cancelled');
  }
}
