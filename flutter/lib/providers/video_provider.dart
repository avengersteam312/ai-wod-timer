import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

/// Recording state enum
enum RecordingState {
  idle,
  initializing,
  ready,
  recording,
  processing,
  completed,
  error,
}

/// Timer overlay style options
enum OverlayStyle {
  minimal,  // Just time text (02:45)
  ring,     // Circular ring + time
  detailed, // Ring + time + round/rest indicator
}

/// Timer overlay size options
enum OverlaySize {
  small,
  medium,
  large,
}

/// Timer frame data captured during recording
class TimerFrame {
  final Duration timestamp;
  final String displayTime;
  final double progress;
  final String? roundIndicator;
  final bool isRest;
  final bool isWork;

  const TimerFrame({
    required this.timestamp,
    required this.displayTime,
    required this.progress,
    this.roundIndicator,
    this.isRest = false,
    this.isWork = true,
  });
}

/// Manages video recording state and settings
class VideoProvider with ChangeNotifier {
  // Camera state
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isFrontCamera = true;
  bool _isFlashOn = false;

  // Recording state
  RecordingState _recordingState = RecordingState.idle;
  String? _errorMessage;
  DateTime? _recordingStartTime;
  Duration _recordingDuration = Duration.zero;

  // Video paths
  String? _rawVideoPath;
  String? _processedVideoPath;

  // Overlay settings
  OverlayStyle _overlayStyle = OverlayStyle.ring;
  OverlaySize _overlaySize = OverlaySize.medium;
  Offset _overlayPosition = const Offset(20, 100);

  // Timer frames captured during recording
  final List<TimerFrame> _timerFrames = [];

  // Getters
  List<CameraDescription> get cameras => _cameras;
  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;
  bool get isFrontCamera => _isFrontCamera;
  bool get isFlashOn => _isFlashOn;

  RecordingState get recordingState => _recordingState;
  bool get isIdle => _recordingState == RecordingState.idle;
  bool get isInitializing => _recordingState == RecordingState.initializing;
  bool get isReady => _recordingState == RecordingState.ready;
  bool get isRecording => _recordingState == RecordingState.recording;
  bool get isProcessing => _recordingState == RecordingState.processing;
  bool get isCompleted => _recordingState == RecordingState.completed;
  bool get hasError => _recordingState == RecordingState.error;
  String? get errorMessage => _errorMessage;

  DateTime? get recordingStartTime => _recordingStartTime;
  Duration get recordingDuration => _recordingDuration;

  String? get rawVideoPath => _rawVideoPath;
  String? get processedVideoPath => _processedVideoPath;

  OverlayStyle get overlayStyle => _overlayStyle;
  OverlaySize get overlaySize => _overlaySize;
  Offset get overlayPosition => _overlayPosition;

  List<TimerFrame> get timerFrames => List.unmodifiable(_timerFrames);

  /// Get overlay size in pixels based on OverlaySize enum
  double get overlaySizePixels {
    switch (_overlaySize) {
      case OverlaySize.small:
        return 80;
      case OverlaySize.medium:
        return 120;
      case OverlaySize.large:
        return 160;
    }
  }

  /// Initialize available cameras
  Future<void> initializeCameras() async {
    if (_cameras.isNotEmpty) return;

    try {
      _recordingState = RecordingState.initializing;
      notifyListeners();

      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        _recordingState = RecordingState.error;
        _errorMessage = 'No cameras available';
        notifyListeners();
        return;
      }

      _recordingState = RecordingState.idle;
      notifyListeners();
    } catch (e) {
      _recordingState = RecordingState.error;
      _errorMessage = 'Failed to initialize cameras: $e';
      notifyListeners();
    }
  }

  /// Initialize camera controller
  Future<void> initializeCamera() async {
    if (_cameras.isEmpty) {
      await initializeCameras();
      if (_cameras.isEmpty) return;
    }

    try {
      _recordingState = RecordingState.initializing;
      _isInitialized = false;
      notifyListeners();

      // Dispose existing controller
      await _cameraController?.dispose();

      // Find appropriate camera
      final cameraIndex = _isFrontCamera
          ? _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front)
          : _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);

      final selectedCamera = cameraIndex >= 0 ? _cameras[cameraIndex] : _cameras.first;

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // Set flash mode for back camera
      if (!_isFrontCamera && _isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }

      _isInitialized = true;
      _recordingState = RecordingState.ready;
      notifyListeners();
    } catch (e) {
      _recordingState = RecordingState.error;
      _errorMessage = 'Failed to initialize camera: $e';
      _isInitialized = false;
      notifyListeners();
    }
  }

  /// Flip between front and back camera
  Future<void> flipCamera() async {
    if (!_isInitialized || _recordingState == RecordingState.recording) return;

    _isFrontCamera = !_isFrontCamera;
    _isFlashOn = false; // Reset flash when switching cameras
    await initializeCamera();
  }

  /// Toggle flash (back camera only)
  Future<void> toggleFlash() async {
    if (!_isInitialized || _isFrontCamera) return;

    try {
      _isFlashOn = !_isFlashOn;
      await _cameraController?.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to toggle flash: $e');
    }
  }

  /// Start video recording
  Future<void> startRecording() async {
    if (!_isInitialized || _cameraController == null) return;
    if (_recordingState == RecordingState.recording) return;

    try {
      await _cameraController!.startVideoRecording();
      _recordingState = RecordingState.recording;
      _recordingStartTime = DateTime.now();
      _recordingDuration = Duration.zero;
      _timerFrames.clear();
      notifyListeners();
    } catch (e) {
      _recordingState = RecordingState.error;
      _errorMessage = 'Failed to start recording: $e';
      notifyListeners();
    }
  }

  /// Stop video recording
  Future<String?> stopRecording() async {
    if (_cameraController == null || _recordingState != RecordingState.recording) {
      return null;
    }

    try {
      final videoFile = await _cameraController!.stopVideoRecording();
      _rawVideoPath = videoFile.path;
      _recordingState = RecordingState.processing;
      notifyListeners();
      return videoFile.path;
    } catch (e) {
      _recordingState = RecordingState.error;
      _errorMessage = 'Failed to stop recording: $e';
      notifyListeners();
      return null;
    }
  }

  /// Update recording duration
  void updateRecordingDuration(Duration duration) {
    _recordingDuration = duration;
    notifyListeners();
  }

  /// Capture timer frame during recording
  void captureTimerFrame(TimerFrame frame) {
    if (_recordingState != RecordingState.recording) return;
    _timerFrames.add(frame);
  }

  /// Set processed video path
  void setProcessedVideoPath(String path) {
    _processedVideoPath = path;
    _recordingState = RecordingState.completed;
    notifyListeners();
  }

  /// Set recording state
  void setRecordingState(RecordingState state) {
    _recordingState = state;
    notifyListeners();
  }

  /// Set error
  void setError(String message) {
    _recordingState = RecordingState.error;
    _errorMessage = message;
    notifyListeners();
  }

  // Overlay settings
  void setOverlayStyle(OverlayStyle style) {
    _overlayStyle = style;
    notifyListeners();
  }

  void setOverlaySize(OverlaySize size) {
    _overlaySize = size;
    notifyListeners();
  }

  void setOverlayPosition(Offset position) {
    _overlayPosition = position;
    notifyListeners();
  }

  /// Constrain overlay position within bounds
  void constrainOverlayPosition(Size screenSize) {
    final overlayDimension = overlaySizePixels;
    const safeArea = 20.0;

    double x = _overlayPosition.dx;
    double y = _overlayPosition.dy;

    // Constrain X
    if (x < safeArea) x = safeArea;
    if (x > screenSize.width - overlayDimension - safeArea) {
      x = screenSize.width - overlayDimension - safeArea;
    }

    // Constrain Y
    if (y < safeArea) y = safeArea;
    if (y > screenSize.height - overlayDimension - safeArea) {
      y = screenSize.height - overlayDimension - safeArea;
    }

    _overlayPosition = Offset(x, y);
    notifyListeners();
  }

  /// Reset to initial state
  void reset() {
    _recordingState = RecordingState.ready;
    _errorMessage = null;
    _recordingStartTime = null;
    _recordingDuration = Duration.zero;
    _rawVideoPath = null;
    _processedVideoPath = null;
    _timerFrames.clear();
    notifyListeners();
  }

  /// Dispose camera controller
  Future<void> disposeCamera() async {
    await _cameraController?.dispose();
    _cameraController = null;
    _isInitialized = false;
    _recordingState = RecordingState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
