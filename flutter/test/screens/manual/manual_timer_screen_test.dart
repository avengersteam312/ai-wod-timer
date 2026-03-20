import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:ai_wod_timer/models/user.dart';
import 'package:ai_wod_timer/providers/auth_provider.dart';
import 'package:ai_wod_timer/providers/workout_provider.dart';
import 'package:ai_wod_timer/screens/manual/manual_timer_screen.dart';
import 'package:ai_wod_timer/services/haptics_service.dart';
import 'package:ai_wod_timer/services/sync_service.dart';
import 'package:ai_wod_timer/theme/app_theme.dart';

class TestAuthProvider extends AuthProvider {
  TestAuthProvider(this._testUser);

  final AppUser? _testUser;

  @override
  AppUser? get user => _testUser;

  @override
  bool get isAuthenticated => _testUser != null;
}

Widget _buildTestApp({
  required AuthProvider authProvider,
  required WorkoutProvider workoutProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: const ManualTimerScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: '''
API_BASE_URL=http://localhost:8000
AUTH_ENABLED=true
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=
''',
    );
    HapticsService.instance.setEnabled(false);
  });

  testWidgets('authenticated users can see the save timer action',
      (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(
          AppUser(
            id: 'user-123',
            email: 'test@example.com',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ),
        workoutProvider: WorkoutProvider(
          syncService: SyncService.test(hasSupabaseConfig: () => false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Save timer'), findsOneWidget);
  });

  testWidgets('rest timer hides countdown while emom shows it', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        authProvider: TestAuthProvider(null),
        workoutProvider: WorkoutProvider(
          syncService: SyncService.test(hasSupabaseConfig: () => false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COUNTDOWN'), findsNothing);

    await tester.tap(find.text('EMOM'));
    await tester.pumpAndSettle();

    expect(find.text('COUNTDOWN'), findsOneWidget);
  });
}
