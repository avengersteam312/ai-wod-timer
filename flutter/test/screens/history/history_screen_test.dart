import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:ai_wod_timer/models/user.dart';
import 'package:ai_wod_timer/models/workout_session.dart';
import 'package:ai_wod_timer/providers/auth_provider.dart';
import 'package:ai_wod_timer/screens/history/history_screen.dart';
import 'package:ai_wod_timer/theme/app_theme.dart';

class TestAuthProvider extends AuthProvider {
  TestAuthProvider(this._testUser);

  final AppUser? _testUser;

  @override
  AppUser? get user => _testUser;

  @override
  bool get isAuthenticated => _testUser != null;
}

WorkoutSession _buildSession({
  required String id,
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
    userId: 'user-123',
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

Widget _buildTestApp({
  required AuthProvider authProvider,
  required Future<List<WorkoutSession>> Function(String userId) loadSessions,
  Future<void> Function(String sessionId)? deleteSession,
  bool isVisible = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: HistoryScreen(
        isVisible: isVisible,
        loadSessions: loadSessions,
        deleteSession: deleteSession,
      ),
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
  });

  testWidgets('renders grouped sessions and summary stats', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    final yesterday = today.subtract(const Duration(days: 1));
    final older = today.subtract(const Duration(days: 8));

    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(
          AppUser(
            id: 'user-123',
            email: 'test@example.com',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ),
        loadSessions: (_) async => [
          _buildSession(
            id: 's1',
            name: 'Fran',
            startedAt: today,
            durationSeconds: 600,
            workSeconds: 480,
            roundsCompleted: 5,
          ),
          _buildSession(
            id: 's2',
            name: 'Cindy',
            startedAt: yesterday,
            durationSeconds: 360,
            workSeconds: 360,
          ),
          _buildSession(
            id: 's3',
            name: 'Murph',
            startedAt: older,
            status: SessionStatus.abandoned,
            durationSeconds: 120,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fran'), findsOneWidget);
    expect(find.text('Cindy'), findsOneWidget);
    expect(find.text('Murph'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Yesterday'), findsWidgets);
    expect(find.text('Timers'), findsOneWidget);
    expect(find.text('16m'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
  });

  testWidgets('shows empty state when there is no history', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        loadSessions: (_) async => [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No History'), findsOneWidget);
    expect(
        find.text('Your completed sessions will appear here.'), findsOneWidget);
  });

  testWidgets('shows error state and retries loading', (tester) async {
    var loadCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        loadSessions: (_) async {
          loadCount++;
          if (loadCount == 1) {
            throw Exception('boom');
          }
          return [];
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Failed to load history'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(find.text('No History'), findsOneWidget);
  });

  testWidgets('deleting a session removes it and calls delete callback',
      (tester) async {
    final deletedIds = <String>[];

    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        loadSessions: (_) async => [
          _buildSession(
            id: 's1',
            name: 'Fran',
            startedAt: DateTime.now(),
          ),
        ],
        deleteSession: (sessionId) async {
          deletedIds.add(sessionId);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Fran'), const Offset(-600, 0));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(deletedIds, ['s1']);
    expect(find.text('Fran'), findsNothing);
  });

  testWidgets('tapping a session opens the details sheet', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        loadSessions: (_) async => [
          _buildSession(
            id: 's1',
            name: 'Fran',
            startedAt: DateTime.now(),
            durationSeconds: 420,
            workSeconds: 300,
            roundsCompleted: 7,
            notes: 'Felt strong today',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fran'));
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Rounds'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Felt strong today'), findsOneWidget);
  });
}
