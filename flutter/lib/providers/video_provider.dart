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
  final String? recordingTime; // Recording duration display (e.g., "01:23")

  const TimerFrame({
    required this.timestamp,
    required this.displayTime,
    required this.progress,
    this.roundIndicator,
    this.isRest = false,
    this.isWork = true,
    this.recordingTime,
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

  // Back camera lenses (iOS multi-lens support)
  CameraDescription? _wideCamera;      // 1x - main camera
  CameraDescription? _ultraWideCamera; // 0.5x
  CameraDescription? _telephotoCamera; // 2x+

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

  // Zoom settings
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  bool _hasUltraWide = false; // 0.5x capability

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

  double get currentZoom => _currentZoom;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  bool get hasUltraWide => _hasUltraWide;

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

      // Detect back camera lenses (iOS multi-lens)
      _detectBackCameraLenses();

      _recordingState = RecordingState.idle;
      notifyListeners();
    } catch (e) {
      _recordingState = RecordingState.error;
      _errorMessage = 'Failed to initialize cameras: $e';
      notifyListeners();
    }
  }

  /// Detect different back camera lenses (ultra-wide, wide, telephoto)
  void _detectBackCameraLenses() {
    final backCameras = _cameras
        .where((c) => c.lensDirection == CameraLensDirection.back)
        .toList();

    debugPrint('[VideoProvider] Found ${backCameras.length} back cameras:');
    for (final cam in backCameras) {
      debugPrint('  - ${cam.name} (${cam.lensDirection})');
    }

    if (backCameras.isEmpty) return;

    // iOS camera device IDs contain a numeric suffix indicating the lens type
    // e.g., "com.apple.avfoundation.avcapturedevice.built-in_video:0"
    // :0 = Wide (main), :2 = Ultra-wide, :5 = Telephoto (5x on Pro Max)
    // We parse the numeric suffix to identify each lens

    for (final camera in backCameras) {
      final name = camera.name;
      // Extract the numeric ID after the last colon
      final colonIndex = name.lastIndexOf(':');
      if (colonIndex >= 0 && colonIndex < name.length - 1) {
        final idStr = name.substring(colonIndex + 1);
        final id = int.tryParse(idStr);
        if (id != null) {
          if (id == 0) {
            _wideCamera = camera; // :0 is always the main wide camera
          } else if (id >= 4) {
            _ultraWideCamera = camera; // :5 = ultra-wide on iPhone 15 Pro Max
          } else {
            _telephotoCamera = camera; // :2 = telephoto on iPhone 15 Pro Max
          }
        }
      }
    }

    // Fallback: if detection failed, use list order
    if (_wideCamera == null && backCameras.isNotEmpty) {
      _wideCamera = backCameras[0];
    }
    if (_ultraWideCamera == null && backCameras.length >= 2) {
      _ultraWideCamera = backCameras[1];
    }
    if (_telephotoCamera == null && backCameras.length >= 3) {
      _telephotoCamera = backCameras[2];
    }

    debugPrint('[VideoProvider] Lens detection:');
    debugPrint('  Wide (1x): ${_wideCamera?.name}');
    debugPrint('  Ultra-wide (0.5x): ${_ultraWideCamera?.name}');
    debugPrint('  Telephoto (2x+): ${_telephotoCamera?.name}');
  }

  /// Initialize camera controller
  Future<void> initializeCamera({CameraDescription? specificCamera}) async {
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
      CameraDescription selectedCamera;
      if (specificCamera != null) {
        selectedCamera = specificCamera;
      } else if (_isFrontCamera) {
        final frontIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        selectedCamera = frontIndex >= 0 ? _cameras[frontIndex] : _cameras.first;
      } else {
        // Default to wide camera (1x) for back
        selectedCamera = _wideCamera ?? _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );
      }

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

      // Initialize zoom levels
      await _initializeZoom();

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

  /// Initialize zoom levels from camera
  Future<void> _initializeZoom() async {
    if (_cameraController == null) return;

    try {
      _minZoom = await _cameraController!.getMinZoomLevel();
      _maxZoom = await _cameraController!.getMaxZoomLevel();

      // Ultra-wide is available if we detected a separate ultra-wide camera
      _hasUltraWide = _ultraWideCamera != null;

      // Reset zoom to 1.0 on current camera
      _currentZoom = 1.0;
      await _cameraController!.setZoomLevel(1.0);

      debugPrint('[VideoProvider] Zoom initialized: min=$_minZoom, max=$_maxZoom, hasUltraWide=$_hasUltraWide');
    } catch (e) {
      debugPrint('[VideoProvider] Failed to initialize zoom: $e');
      _minZoom = 1.0;
      _maxZoom = 1.0;
      _currentZoom = 1.0;
      _hasUltraWide = false;
    }
  }

  /// Set zoom level - switches cameras for 0.5x, 1x, 2x on back camera
  Future<void> setZoom(double zoom) async {
    if (!_isInitialized || _cameraController == null) return;

    // Front camera: only digital zoom
    if (_isFrontCamera) {
      try {
        final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
        await _cameraController!.setZoomLevel(clampedZoom);
        _currentZoom = clampedZoom;
        notifyListeners();
      } catch (e) {
        debugPrint('[VideoProvider] Failed to set zoom: $e');
      }
      return;
    }

    // Back camera: switch lenses for 0.5x, 1x, 2x
    try {
      CameraDescription? targetCamera;
      double targetZoomLevel = 1.0;

      if (zoom == 0.5 && _ultraWideCamera != null) {
        targetCamera = _ultraWideCamera;
        targetZoomLevel = 1.0;
      } else if (zoom == 2.0 && _telephotoCamera != null) {
        targetCamera = _telephotoCamera;
        targetZoomLevel = 1.0;
      } else if (zoom == 1.0) {
        targetCamera = _wideCamera;
        targetZoomLevel = 1.0;
      } else {
        // 1.5x or other: digital zoom on wide camera
        targetCamera = _wideCamera;
        targetZoomLevel = zoom;
      }

      final currentCameraName = _cameraController!.description.name;

      if (targetCamera != null && targetCamera.name != currentCameraName) {
        debugPrint('[VideoProvider] Switching to ${targetCamera.name} for ${zoom}x');

        await _cameraController!.dispose();

        _cameraController = CameraController(
          targetCamera,
          ResolutionPreset.high,
          enableAudio: true,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );

        await _cameraController!.initialize();

        _minZoom = await _cameraController!.getMinZoomLevel();
        _maxZoom = await _cameraController!.getMaxZoomLevel();

        if (_isFlashOn) {
          await _cameraController!.setFlashMode(FlashMode.torch);
        }
      }

      final clampedZoom = targetZoomLevel.clamp(_minZoom, _maxZoom);
      await _cameraController!.setZoomLevel(clampedZoom);
      _currentZoom = zoom;
      notifyListeners();
      debugPrint('[VideoProvider] Zoom set to: $zoom');
    } catch (e) {
      debugPrint('[VideoProvider] Failed to set zoom: $e');
    }
  }

  /// Get available zoom presets based on current camera
  List<double> get zoomPresets {
    if (_isFrontCamera) {
      // Front camera: only digital zoom
      return [1.0, 2.0];
    }

    // Back camera: show lens options
    final presets = <double>[];

    if (_ultraWideCamera != null) {
      presets.add(0.5);
    }

    presets.add(1.0);
    presets.add(1.5);
    presets.add(2.0);

    return presets;
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
    _currentZoom = 1.0;
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
