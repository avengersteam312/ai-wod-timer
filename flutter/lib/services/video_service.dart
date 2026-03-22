import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/video_provider.dart';
import 'ffmpeg_service.dart';

/// Video export format options
enum VideoExportFormat {
  original, // Original aspect ratio
  square, // 1:1 (Instagram feed)
  portrait, // 9:16 (TikTok, Reels, Stories)
}

/// Service for video recording and post-processing
class VideoService {
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  /// Generate output path for video file
  Future<String> getOutputPath({String prefix = 'wod_video'}) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/${prefix}_$timestamp.mp4';
  }

  /// Process video with FFmpeg to bake in timer overlay, watermark, and date
  /// Falls back to simple copy if no timer frames or FFmpeg fails
  Future<String?> processVideo({
    required String inputPath,
    VideoExportFormat format = VideoExportFormat.original,
    List<TimerFrame>? timerFrames,
    DateTime? recordingDate,
    FFmpegProgressCallback? onProgress,
  }) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        debugPrint('[VideoService] Input file does not exist: $inputPath');
        return null;
      }

      // If we have timer frames, use FFmpeg to bake in overlays
      if (timerFrames != null && timerFrames.isNotEmpty) {
        debugPrint(
            '[VideoService] Processing video with ${timerFrames.length} timer frames');

        final processedPath = await FFmpegService().processVideoWithOverlay(
          inputPath: inputPath,
          frames: timerFrames,
          recordingDate: recordingDate ?? DateTime.now(),
          onProgress: onProgress,
        );

        if (processedPath != null) {
          debugPrint('[VideoService] FFmpeg processing successful');
          return processedPath;
        }

        // FFmpeg failed, fall back to simple copy
        debugPrint(
            '[VideoService] FFmpeg processing failed, falling back to copy');
      }

      // Simple copy fallback (no timer overlay)
      final outputPath = await getOutputPath(prefix: 'wod_processed');
      await inputFile.copy(outputPath);
      debugPrint('[VideoService] Video copied to: $outputPath');
      return outputPath;
    } catch (e) {
      debugPrint('[VideoService] Error processing video: $e');
      return null;
    }
  }

  /// Save video to device gallery
  Future<bool> saveToGallery(String videoPath) async {
    try {
      final result = await GallerySaver.saveVideo(videoPath);
      debugPrint('[VideoService] Save to gallery result: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('[VideoService] Error saving to gallery: $e');
      return false;
    }
  }

  /// Share video to other apps
  /// On iPad, sharePositionOrigin is required
  Future<void> shareVideo(String videoPath,
      {String? text, Rect? sharePositionOrigin}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(videoPath)],
          text: text ?? 'Check out my workout!',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (e) {
      debugPrint('[VideoService] Error sharing video: $e');
    }
  }

  /// Delete temporary video file
  Future<void> deleteVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[VideoService] Deleted video: $videoPath');
      }
    } catch (e) {
      debugPrint('[VideoService] Error deleting video: $e');
    }
  }

  /// Get video file size in MB
  Future<double?> getVideoSizeMB(String videoPath) async {
    try {
      final file = File(videoPath);
      if (await file.exists()) {
        final bytes = await file.length();
        return bytes / (1024 * 1024);
      }
      return null;
    } catch (e) {
      debugPrint('[VideoService] Error getting file size: $e');
      return null;
    }
  }

  /// Clean up temporary video files
  Future<void> cleanupTempVideos() async {
    try {
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();
      for (final file in files) {
        if (file is File && file.path.contains('wod_')) {
          await file.delete();
        }
      }
      debugPrint('[VideoService] Cleaned up temp videos');
    } catch (e) {
      debugPrint('[VideoService] Error cleaning up temp videos: $e');
    }
  }
}
