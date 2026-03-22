import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ai_wod_timer/main.dart' as app;
import 'package:ai_wod_timer/ui_test_keys.dart';

const _e2eEmail = String.fromEnvironment('E2E_TEST_EMAIL');
const _e2ePassword = String.fromEnvironment('E2E_TEST_PASSWORD');
final _hasCredentials = _e2eEmail.isNotEmpty && _e2ePassword.isNotEmpty;

Future<void> _pumpApp(WidgetTester tester) async {
  await app.main();
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> _signIn(WidgetTester tester) async {
  expect(find.byKey(UiTestKeys.authButton), findsOneWidget);

  await tester.tap(find.byKey(UiTestKeys.authButton));
  await tester.pumpAndSettle();

  if (find.text('Sign Out').evaluate().isNotEmpty) {
    final isExpectedUserSignedIn = find.text(_e2eEmail).evaluate().isNotEmpty;
    if (isExpectedUserSignedIn) {
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      return;
    }

    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );

    await tester.tap(find.byKey(UiTestKeys.authButton));
    await tester.pumpAndSettle();
  }

  expect(find.byKey(UiTestKeys.loginEmailField), findsOneWidget);
  expect(find.byKey(UiTestKeys.loginPasswordField), findsOneWidget);
  expect(find.byKey(UiTestKeys.loginSubmitButton), findsOneWidget);

  await tester.enterText(find.byKey(UiTestKeys.loginEmailField), _e2eEmail);
  await tester.pump();
  await tester.enterText(
      find.byKey(UiTestKeys.loginPasswordField), _e2ePassword);
  // Wait for any loading states triggered by text input to settle before tapping.
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
  await tester.tap(find.byKey(UiTestKeys.loginSubmitButton));
  await tester.pump();
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> _signOut(WidgetTester tester) async {
  await tester.tap(find.byKey(UiTestKeys.authButton));
  await tester.pumpAndSettle();
  expect(find.text('Sign Out'), findsOneWidget);
  await tester.tap(find.text('Sign Out'));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> _waitForFinder(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final maxTicks = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (int i = 0; i < maxTicks; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(step);
  }
  expect(finder, findsOneWidget);
}

Future<void> _waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final maxTicks = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (int i = 0; i < maxTicks; i++) {
    if (finder.evaluate().isEmpty) {
      return;
    }
    await tester.pump(step);
  }
  expect(finder, findsNothing);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real auth flow signs in and gates save controls by session state',
    (tester) async {
      await _pumpApp(tester);
      await _signIn(tester);

      await tester.tap(find.byKey(UiTestKeys.manualTab));
      await tester.pumpAndSettle();
      expect(find.byKey(UiTestKeys.manualSaveButton), findsOneWidget);

      await _signOut(tester);
      expect(find.byKey(UiTestKeys.manualSaveButton), findsNothing);
      // Drain all pending async operations before teardown to prevent
      // "FocusManager used after disposed" errors.
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
    },
    skip: !_hasCredentials,
  );

  testWidgets(
    'real auth flow saves an AI-created timer into saved timers',
    (tester) async {
      final timerName =
          'E2E ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      await _pumpApp(tester);
      await _signIn(tester);

      await tester.tap(find.byKey(UiTestKeys.dashboardTab));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(UiTestKeys.dashboardTextInput),
        'Create a simple EMOM with one 30 second work interval called $timerName',
      );
      await tester.tap(find.byKey(UiTestKeys.dashboardCreateTimerButton));
      await tester.pump();
      // 60s timeout — staging is on free tier and may cold-start during AI parse.
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 60),
      );

      expect(find.byKey(UiTestKeys.manualSaveButton), findsOneWidget);

      await tester.tap(find.byKey(UiTestKeys.manualSaveButton));
      await tester.pumpAndSettle();
      expect(find.byKey(UiTestKeys.saveTemplateNameField), findsOneWidget);

      await tester.enterText(
          find.byKey(UiTestKeys.saveTemplateNameField), timerName);
      await tester.tap(find.byKey(UiTestKeys.saveTemplateSubmitButton));
      await tester.pump();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );

      await _waitForGone(
        tester,
        find.byKey(UiTestKeys.saveTemplateNameField),
      );
      await _waitForGone(
        tester,
        find.byType(BottomSheet),
      );
      expect(find.byKey(UiTestKeys.timerCancelButton), findsOneWidget);
      await tester.ensureVisible(find.byKey(UiTestKeys.timerCancelButton));
      await tester.tap(find.byKey(UiTestKeys.timerCancelButton));
      await tester.pumpAndSettle();

      expect(find.byKey(UiTestKeys.dashboardCreateTimerButton), findsOneWidget);

      await _waitForFinder(
        tester,
        find.byKey(UiTestKeys.dashboardViewAllSavedWorkouts),
      );
      await tester.ensureVisible(
        find.byKey(UiTestKeys.dashboardViewAllSavedWorkouts),
      );
      expect(
        find.byKey(UiTestKeys.dashboardViewAllSavedWorkouts),
        findsOneWidget,
      );
      await tester.tap(find.byKey(UiTestKeys.dashboardViewAllSavedWorkouts));
      await tester.pumpAndSettle();

      expect(find.byKey(UiTestKeys.myWorkoutsScreen), findsOneWidget);
      expect(find.text(timerName), findsOneWidget);

      final savedWorkoutRow = find
          .ancestor(
            of: find.text(timerName),
            matching: find.byType(Dismissible),
          )
          .first;
      await tester.drag(savedWorkoutRow, const Offset(-600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text(timerName), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
    },
    skip: !_hasCredentials,
  );
}
