import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:ai_wod_timer/models/user.dart';
import 'package:ai_wod_timer/models/workout.dart';
import 'package:ai_wod_timer/providers/auth_provider.dart';
import 'package:ai_wod_timer/providers/workout_provider.dart';
import 'package:ai_wod_timer/screens/workouts/my_workouts_screen.dart';
import 'package:ai_wod_timer/services/haptics_service.dart';
import 'package:ai_wod_timer/theme/app_theme.dart';

class TestAuthProvider extends AuthProvider {
  TestAuthProvider(this._testUser);

  final AppUser? _testUser;

  @override
  AppUser? get user => _testUser;
}

class TestWorkoutProvider extends WorkoutProvider {
  Workout? selectedWorkout;
  String? selectedFromSavedWorkoutId;

  @override
  void setWorkout(Workout workout, {String? fromSavedWorkoutId}) {
    selectedWorkout = workout;
    selectedFromSavedWorkoutId = fromSavedWorkoutId;
  }
}

Workout _buildWorkout({
  required String id,
  required String name,
  bool isFavorite = false,
}) {
  return Workout(
    id: id,
    userId: 'user-123',
    name: name,
    type: WorkoutType.emom,
    timerConfig: TimerConfig(
      intervals: const [],
      totalSeconds: 600,
      rounds: 10,
    ),
    movements: const [],
    isFavorite: isFavorite,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Widget _buildTestApp({
  required AuthProvider authProvider,
  required WorkoutProvider workoutProvider,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(
      envString: '''
API_BASE_URL=http://localhost:8000
AUTH_ENABLED=false
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=
''',
    );
    HapticsService.instance.setEnabled(false);
  });

  testWidgets('renders saved timers from loader', (tester) async {
    final authProvider = TestAuthProvider(
      AppUser(
        id: 'user-123',
        email: 'test@example.com',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final workoutProvider = TestWorkoutProvider();
    late String requestedUserId;

    await tester.pumpWidget(
      _buildTestApp(
        authProvider: authProvider,
        workoutProvider: workoutProvider,
        child: MyWorkoutsScreen(
          loadWorkouts: (userId) async {
            requestedUserId = userId;
            return [
              _buildWorkout(id: 'w1', name: 'Fran'),
              _buildWorkout(id: 'w2', name: 'Cindy'),
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedUserId, 'user-123');
    expect(find.text('Fran'), findsOneWidget);
    expect(find.text('Cindy'), findsOneWidget);
    expect(find.text('Saved Timers'), findsOneWidget);
  });

  testWidgets('shows empty state when no saved timers exist', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        workoutProvider: TestWorkoutProvider(),
        child: MyWorkoutsScreen(
          loadWorkouts: (_) async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Workouts Yet'), findsOneWidget);
    expect(find.textContaining('Your saved workouts will appear here'),
        findsOneWidget);
  });

  testWidgets('shows error state when loading fails', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        workoutProvider: TestWorkoutProvider(),
        child: MyWorkoutsScreen(
          loadWorkouts: (_) async => throw Exception('boom'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Failed to load templates'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('refresh button reloads workouts', (tester) async {
    var loadCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        workoutProvider: TestWorkoutProvider(),
        child: MyWorkoutsScreen(
          loadWorkouts: (_) async {
            loadCount++;
            return [_buildWorkout(id: 'w1', name: 'Fran')];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loadCount, 2);
  });

  testWidgets('tapping a workout starts it and navigates to timer',
      (tester) async {
    final workoutProvider = TestWorkoutProvider();
    var navigateCount = 0;
    final workout = _buildWorkout(id: 'w1', name: 'Fran');

    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        workoutProvider: workoutProvider,
        child: MyWorkoutsScreen(
          onNavigateToTimer: () => navigateCount++,
          loadWorkouts: (_) async => [workout],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fran'));
    await tester.pumpAndSettle();

    expect(workoutProvider.selectedWorkout?.id, 'w1');
    expect(workoutProvider.selectedFromSavedWorkoutId, 'w1');
    expect(navigateCount, 1);
  });

  testWidgets('favorite toggle updates workout on success', (tester) async {
    Workout? updatedWorkout;

    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        workoutProvider: TestWorkoutProvider(),
        child: MyWorkoutsScreen(
          loadWorkouts: (_) async => [
            _buildWorkout(id: 'w1', name: 'Fran', isFavorite: false),
          ],
          updateWorkout: (workout) async {
            updatedWorkout = workout;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pumpAndSettle();

    expect(updatedWorkout?.isFavorite, isTrue);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('favorite toggle shows error when update fails', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        workoutProvider: TestWorkoutProvider(),
        child: MyWorkoutsScreen(
          loadWorkouts: (_) async => [
            _buildWorkout(id: 'w1', name: 'Fran', isFavorite: false),
          ],
          updateWorkout: (_) async => throw Exception('failed'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Failed to update timer'), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('delete cancel keeps the timer', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        workoutProvider: TestWorkoutProvider(),
        child: MyWorkoutsScreen(
          loadWorkouts: (_) async => [_buildWorkout(id: 'w1', name: 'Fran')],
          deleteWorkout: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Fran'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete Template'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Fran'), findsOneWidget);
  });

  testWidgets('delete confirm removes the timer and shows success',
      (tester) async {
    final deletedIds = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        workoutProvider: TestWorkoutProvider(),
        child: MyWorkoutsScreen(
          loadWorkouts: (_) async => [_buildWorkout(id: 'w1', name: 'Fran')],
          deleteWorkout: (id) async {
            deletedIds.add(id);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Fran'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(deletedIds, ['w1']);
    expect(find.text('Fran'), findsNothing);
    expect(find.text('Template deleted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('delete failure reloads list and shows error', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        workoutProvider: TestWorkoutProvider(),
        child: MyWorkoutsScreen(
          loadWorkouts: (_) async => [_buildWorkout(id: 'w1', name: 'Fran')],
          deleteWorkout: (_) async => throw Exception('failed'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Fran'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Fran'), findsOneWidget);
    expect(find.text('Failed to delete template'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}
