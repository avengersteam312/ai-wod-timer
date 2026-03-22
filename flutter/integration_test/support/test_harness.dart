import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ai_wod_timer/app_bootstrap.dart';
import 'package:ai_wod_timer/app_bootstrap.dart' as app;
import 'package:ai_wod_timer/models/user.dart';
import 'package:ai_wod_timer/models/workout.dart';
import 'package:ai_wod_timer/models/workout_session.dart';
import 'package:ai_wod_timer/providers/auth_provider.dart';
import 'package:ai_wod_timer/providers/video_provider.dart';
import 'package:ai_wod_timer/providers/workout_provider.dart';
import 'package:ai_wod_timer/services/api_service.dart';
import 'package:ai_wod_timer/services/haptics_service.dart';
import 'package:ai_wod_timer/services/offline_storage_service.dart';
import 'package:ai_wod_timer/services/sync_service.dart';

const testPreviewCloseButtonKey = ValueKey<String>('test_video_preview_close');

class InMemoryOfflineStorageService extends OfflineStorageService {
  InMemoryOfflineStorageService() : super.test();

  final Map<String, Workout> workouts = {};
  final Map<String, WorkoutSession> sessions = {};
  final Map<String, SyncOperation> queue = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> saveWorkout(Workout workout) async {
    workouts[workout.id] = workout;
  }

  @override
  Future<void> saveWorkouts(List<Workout> values) async {
    for (final workout in values) {
      workouts[workout.id] = workout;
    }
  }

  @override
  Future<List<Workout>> getWorkouts(String userId) async {
    final values = workouts.values.where((w) => w.userId == userId).toList();
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  @override
  Future<Workout?> getWorkout(String id) async => workouts[id];

  @override
  Future<void> deleteWorkout(String id) async {
    workouts.remove(id);
  }

  @override
  Future<void> clearWorkouts() async {
    workouts.clear();
  }

  @override
  Future<void> saveSession(WorkoutSession session) async {
    sessions[session.id] = session;
  }

  @override
  Future<void> saveSessions(List<WorkoutSession> values) async {
    for (final session in values) {
      sessions[session.id] = session;
    }
  }

  @override
  Future<List<WorkoutSession>> getSessions(String userId) async {
    final values = sessions.values.where((s) => s.userId == userId).toList();
    values.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return values;
  }

  @override
  Future<WorkoutSession?> getSession(String id) async => sessions[id];

  @override
  Future<void> deleteSession(String id) async {
    sessions.remove(id);
  }

  @override
  Future<void> clearSessions() async {
    sessions.clear();
  }

  @override
  Future<void> addToSyncQueue(SyncOperation operation) async {
    queue[operation.id] = operation;
  }

  @override
  Future<List<SyncOperation>> getSyncQueue() async {
    final values = queue.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return values;
  }

  @override
  Future<void> removeFromSyncQueue(String id) async {
    queue.remove(id);
  }

  @override
  Future<void> clearSyncQueue() async {
    queue.clear();
  }

  @override
  Future<void> clearAll() async {
    workouts.clear();
    sessions.clear();
    queue.clear();
  }
}

class FakeVideoProvider extends VideoProvider {
  FakeVideoProvider({this.previewPath = '/tmp/ai_wod_timer_test.mov'});

  final String previewPath;

  bool _isInitialized = true;
  bool _isFrontCamera = true;
  bool _isFlashOn = false;
  RecordingState _state = RecordingState.ready;
  String? _errorMessage;
  DateTime? _recordingStartTime;
  Duration _recordingDuration = Duration.zero;
  String? _processedVideoPath;
  OverlayStyle _overlayStyle = OverlayStyle.ring;
  OverlaySize _overlaySize = OverlaySize.medium;
  Offset _overlayPosition = const Offset(20, 100);

  @override
  CameraController? get cameraController => null;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isFrontCamera => _isFrontCamera;

  @override
  bool get isFlashOn => _isFlashOn;

  @override
  RecordingState get recordingState => _state;

  @override
  bool get isIdle => _state == RecordingState.idle;

  @override
  bool get isInitializing => _state == RecordingState.initializing;

  @override
  bool get isReady => _state == RecordingState.ready;

  @override
  bool get isRecording => _state == RecordingState.recording;

  @override
  bool get isProcessing => _state == RecordingState.processing;

  @override
  bool get isCompleted => _state == RecordingState.completed;

  @override
  bool get hasError => _state == RecordingState.error;

  @override
  String? get errorMessage => _errorMessage;

  @override
  DateTime? get recordingStartTime => _recordingStartTime;

  @override
  Duration get recordingDuration => _recordingDuration;

  @override
  String? get processedVideoPath => _processedVideoPath;

  @override
  OverlayStyle get overlayStyle => _overlayStyle;

  @override
  OverlaySize get overlaySize => _overlaySize;

  @override
  Offset get overlayPosition => _overlayPosition;

  @override
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

  @override
  Future<void> initializeCameras() async {
    _state = RecordingState.ready;
    notifyListeners();
  }

  @override
  Future<void> initializeCamera({CameraDescription? specificCamera}) async {
    _state = RecordingState.initializing;
    notifyListeners();
    _isInitialized = true;
    _state = RecordingState.ready;
    notifyListeners();
  }

  @override
  Future<void> startRecording() async {
    _recordingStartTime = DateTime.now();
    _recordingDuration = Duration.zero;
    _state = RecordingState.recording;
    notifyListeners();
  }

  @override
  Future<String?> stopRecording() async {
    _state = RecordingState.processing;
    notifyListeners();
    return previewPath;
  }

  @override
  void updateRecordingDuration(Duration duration) {
    _recordingDuration = duration;
    notifyListeners();
  }

  @override
  void captureTimerFrame(TimerFrame frame) {}

  @override
  void setProcessedVideoPath(String path) {
    _processedVideoPath = path;
    _state = RecordingState.completed;
    notifyListeners();
  }

  @override
  void setRecordingState(RecordingState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void setError(String message) {
    _errorMessage = message;
    _state = RecordingState.error;
    notifyListeners();
  }

  @override
  void setOverlayStyle(OverlayStyle style) {
    _overlayStyle = style;
    notifyListeners();
  }

  @override
  void setOverlaySize(OverlaySize size) {
    _overlaySize = size;
    notifyListeners();
  }

  @override
  void setOverlayPosition(Offset position) {
    _overlayPosition = position;
    notifyListeners();
  }

  @override
  void constrainOverlayPosition(Size screenSize) {
    _overlayPosition = Offset(
      _overlayPosition.dx.clamp(0.0, screenSize.width).toDouble(),
      _overlayPosition.dy.clamp(0.0, screenSize.height).toDouble(),
    );
    notifyListeners();
  }

  @override
  Future<void> flipCamera() async {
    _isFrontCamera = !_isFrontCamera;
    notifyListeners();
  }

  @override
  Future<void> toggleFlash() async {
    _isFlashOn = !_isFlashOn;
    notifyListeners();
  }

  @override
  void reset() {
    _errorMessage = null;
    _recordingStartTime = null;
    _recordingDuration = Duration.zero;
    _processedVideoPath = null;
    _state = RecordingState.ready;
    notifyListeners();
  }

  @override
  Future<void> disposeCamera() async {
    _isInitialized = false;
    _state = RecordingState.idle;
    notifyListeners();
  }
}

class FakeImagePicker extends ImagePicker {
  FakeImagePicker(this.imagePath);

  final String imagePath;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return XFile(imagePath);
  }
}

class TestVideoPreviewScreen extends StatelessWidget {
  const TestVideoPreviewScreen({super.key, required this.videoPath});

  final String videoPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: testPreviewCloseButtonKey,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Preview ready'),
      ),
      body: Center(child: Text(videoPath)),
    );
  }
}

class AppTestHarness {
  AppTestHarness({
    AppUser? user,
    List<Workout>? savedWorkouts,
    List<WorkoutSession>? savedSessions,
    Map<String, dynamic>? parseResponse,
    Map<String, dynamic>? parseImageResponse,
    Workout? initialWorkout,
    String? fromSavedWorkoutId,
    FakeVideoProvider? videoProvider,
    this.imagePicker,
  })  : storage = InMemoryOfflineStorageService(),
        authProvider = AuthProvider.test(user: user),
        _parseResponse = parseResponse,
        _parseImageResponse = parseImageResponse,
        _initialWorkout = initialWorkout,
        _fromSavedWorkoutId = fromSavedWorkoutId,
        videoProvider = videoProvider ?? FakeVideoProvider() {
    syncService = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => false,
    );
    workoutProvider = WorkoutProvider(
      apiService: ApiService.test(
        parseWorkoutOverride: (input) async =>
            _parseResponse ?? defaultParseResponse(input: input),
        parseWorkoutFromImageOverride: (imageFile) async =>
            _parseImageResponse ??
            defaultParseResponse(input: imageFile.path.split('/').last),
      ),
      syncService: syncService,
    );

    if (savedWorkouts != null) {
      for (final workout in savedWorkouts) {
        storage.workouts[workout.id] = workout;
      }
    }
    if (savedSessions != null) {
      for (final session in savedSessions) {
        storage.sessions[session.id] = session;
      }
    }
    if (_initialWorkout != null) {
      workoutProvider.setWorkout(
        _initialWorkout!,
        fromSavedWorkoutId: _fromSavedWorkoutId,
      );
    }
  }

  final InMemoryOfflineStorageService storage;
  final AuthProvider authProvider;
  final Map<String, dynamic>? _parseResponse;
  final Map<String, dynamic>? _parseImageResponse;
  final Workout? _initialWorkout;
  final String? _fromSavedWorkoutId;
  final FakeVideoProvider videoProvider;
  final ImagePicker? imagePicker;

  late final SyncService syncService;
  late final WorkoutProvider workoutProvider;

  static Future<void> initializeTestEnvironment() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.loadFromString(
      envString: '''
API_BASE_URL=http://localhost:8000
AUTH_ENABLED=true
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=
''',
    );
    HapticsService.instance.setEnabled(false);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(
      app.MyApp(
        bootstrap: AppBootstrap(
          createAuthProvider: () => authProvider,
          createWorkoutProvider: () => workoutProvider,
          createVideoProvider: () => videoProvider,
          shellDependencies: AppShellDependencies(
            syncService: syncService,
            imagePicker: imagePicker,
            videoPreviewBuilder: (videoPath) =>
                TestVideoPreviewScreen(videoPath: videoPath),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  }

  static AppUser buildUser({
    String id = 'user-123',
    String email = 'test@example.com',
  }) {
    return AppUser(
      id: id,
      email: email,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  static Workout buildWorkout({
    required String id,
    required String name,
    required String userId,
    WorkoutType type = WorkoutType.emom,
    List<TimerInterval>? intervals,
    bool hasCountdown = false,
    int countdownSeconds = 0,
    String? rawInput,
    String? notes,
    bool isFavorite = false,
  }) {
    final effectiveIntervals =
        intervals ?? const [TimerInterval(duration: 5, type: 'work')];

    return Workout(
      id: id,
      userId: userId,
      name: name,
      rawInput: rawInput,
      notes: notes,
      type: type,
      timerConfig: TimerConfig(
        intervals: effectiveIntervals,
        hasCountdown: hasCountdown,
        countdownSeconds: countdownSeconds,
        totalSeconds:
            effectiveIntervals.fold<int>(0, (sum, i) => sum + i.duration),
        rounds: effectiveIntervals.where((i) => i.isWork).length,
        intervalSeconds: effectiveIntervals.first.duration,
      ),
      movements: const [],
      isFavorite: isFavorite,
      createdAt: DateTime.utc(2026, 1, 1, 12),
    );
  }

  static WorkoutSession buildSession({
    required String id,
    required String userId,
    required String name,
    required DateTime startedAt,
    SessionStatus status = SessionStatus.completed,
    int durationSeconds = 300,
    int? workSeconds,
    int? roundsCompleted,
    String? notes,
  }) {
    return WorkoutSession(
      id: id,
      userId: userId,
      workoutName: name,
      workoutType: 'emom',
      workoutSnapshot: const {},
      status: status,
      durationSeconds: durationSeconds,
      workSeconds: workSeconds,
      roundsCompleted: roundsCompleted,
      notes: notes,
      startedAt: startedAt,
    );
  }

  static Map<String, dynamic> defaultParseResponse({String input = 'Fran'}) {
    return {
      'name': input,
      'workout_type': 'emom',
      'timer_config': {
        'intervals': [
          {'duration': 5, 'type': 'work'}
        ],
        'has_countdown': false,
        'countdown_seconds': 0,
        'total_seconds': 5,
        'rounds': 1,
        'interval_seconds': 5,
      },
      'movements': const [],
    };
  }
}
