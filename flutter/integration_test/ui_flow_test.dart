import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ai_wod_timer/models/workout.dart';
import 'package:ai_wod_timer/ui_test_keys.dart';

import 'support/test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppTestHarness.initializeTestEnvironment();
  });

  testWidgets('shell smoke test covers tab navigation anchors', (tester) async {
    final harness = AppTestHarness();

    await harness.pumpApp(tester);

    expect(find.byKey(UiTestKeys.manualTab), findsOneWidget);
    expect(find.byKey(UiTestKeys.dashboardTab), findsOneWidget);
    expect(find.byKey(UiTestKeys.historyTab), findsOneWidget);
    expect(find.byKey(UiTestKeys.dashboardCreateTimerButton), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.manualTab));
    await tester.pumpAndSettle();
    expect(find.byKey(UiTestKeys.manualStartButton), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.historyTab));
    await tester.pumpAndSettle();
    expect(find.byKey(UiTestKeys.historyScreen), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.dashboardTab));
    await tester.pumpAndSettle();
    expect(find.byKey(UiTestKeys.dashboardTextInput), findsOneWidget);
  });

  testWidgets(
      'manual timer flow starts, pauses, resumes, completes, and persists history',
      (tester) async {
    final harness = AppTestHarness();

    await harness.pumpApp(tester);

    await tester.tap(find.byKey(UiTestKeys.manualTab));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30s'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(UiTestKeys.timerPlayPauseButton));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(UiTestKeys.timerPlayPauseButton));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.byKey(UiTestKeys.timerStopButton));
    await tester.pumpAndSettle();

    expect(harness.storage.sessions.length, 1);

    await tester.tap(find.byKey(UiTestKeys.historyTab));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        UiTestKeys.historySession(harness.storage.sessions.keys.first),
      ),
      findsOneWidget,
    );
  });

  testWidgets('dashboard text parsing creates a timer and enters active state',
      (tester) async {
    final user = AppTestHarness.buildUser();
    final harness = AppTestHarness(
      user: user,
      parseResponse: AppTestHarness.defaultParseResponse(input: 'Fran'),
    );

    await harness.pumpApp(tester);

    await tester.enterText(find.byKey(UiTestKeys.dashboardTextInput), 'Fran');
    await tester.tap(find.byKey(UiTestKeys.dashboardCreateTimerButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(UiTestKeys.timerEditAction), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.timerPlayPauseButton));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.pause), findsWidgets);
    expect(find.byKey(UiTestKeys.timerStopButton), findsOneWidget);
  });

  testWidgets('dashboard image upload creates a timer and can be closed',
      (tester) async {
    final user = AppTestHarness.buildUser();
    final fixturePath =
        File('integration_test/fixtures/for_time_workout.png').absolute.path;
    final harness = AppTestHarness(
      user: user,
      imagePicker: FakeImagePicker(fixturePath),
      parseImageResponse: {
        'name': 'Fixture For Time',
        'workout_type': 'for_time',
        'timer_config': {
          'intervals': [
            {'duration': 300, 'type': 'work'},
          ],
          'has_countdown': false,
          'countdown_seconds': 0,
          'total_seconds': 300,
          'rounds': 1,
          'interval_seconds': 300,
        },
        'movements': const [],
      },
    );

    await harness.pumpApp(tester);

    await tester.tap(find.byKey(UiTestKeys.authButton));
    await tester.pumpAndSettle();
    expect(find.text('Sign Out'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(UiTestKeys.dashboardImageModeToggle));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UiTestKeys.dashboardChooseGalleryButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(UiTestKeys.timerCancelButton), findsOneWidget);
    expect(find.byKey(UiTestKeys.timerPlayPauseButton), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.timerCancelButton));
    await tester.pumpAndSettle();
    expect(find.byKey(UiTestKeys.saveTemplateCancelButton), findsOneWidget);
    await tester.tap(find.byKey(UiTestKeys.saveTemplateCancelButton));
    await tester.pumpAndSettle();

    expect(find.byKey(UiTestKeys.dashboardChooseGalleryButton), findsOneWidget);
  });

  testWidgets(
      'authenticated dashboard image upload can save to dashboard and drag-delete',
      (tester) async {
    final user = AppTestHarness.buildUser();
    final fixturePath =
        File('integration_test/fixtures/for_time_workout.png').absolute.path;
    final harness = AppTestHarness(
      user: user,
      imagePicker: FakeImagePicker(fixturePath),
      parseImageResponse: {
        'name': 'Fixture For Time',
        'workout_type': 'for_time',
        'timer_config': {
          'intervals': [
            {'duration': 300, 'type': 'work'},
          ],
          'has_countdown': false,
          'countdown_seconds': 0,
          'total_seconds': 300,
          'rounds': 1,
          'interval_seconds': 300,
        },
        'movements': const [],
      },
    );
    const timerName = 'Img Delete';

    await harness.pumpApp(tester);

    await tester.tap(find.byKey(UiTestKeys.authButton));
    await tester.pumpAndSettle();
    expect(find.text('Sign Out'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(UiTestKeys.dashboardImageModeToggle));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UiTestKeys.dashboardChooseGalleryButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(UiTestKeys.timerCancelButton), findsOneWidget);
    await tester.tap(find.byKey(UiTestKeys.timerCancelButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(UiTestKeys.saveTemplateNameField),
      timerName,
    );
    await tester.tap(find.byKey(UiTestKeys.saveTemplateSubmitButton));
    await tester.pump();
    await tester.pumpAndSettle();

    for (int i = 0;
        i < 20 &&
            find.byKey(UiTestKeys.saveTemplateNameField).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    for (int i = 0;
        i < 20 && find.byType(BottomSheet).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.byKey(UiTestKeys.dashboardScreen), findsOneWidget);

    for (int i = 0; i < 20 && find.text(timerName).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text(timerName), findsOneWidget);

    final cardFinder = find
        .ancestor(
          of: find.text(timerName),
          matching: find.byType(LongPressDraggable<Workout>),
        )
        .first;
    final gesture = await tester.startGesture(tester.getCenter(cardFinder));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Drag here to delete'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('Drag here to delete')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text(timerName), findsNothing);
    expect(
      harness.storage.workouts.values
          .any((workout) => workout.name == timerName),
      isFalse,
    );
  });

  testWidgets('dashboard image upload is auth-gated for guests',
      (tester) async {
    final harness = AppTestHarness();

    await harness.pumpApp(tester);

    await tester.tap(find.byKey(UiTestKeys.dashboardImageModeToggle));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UiTestKeys.dashboardChooseGalleryButton));
    await tester.pumpAndSettle();

    expect(find.byKey(UiTestKeys.loginEmailField), findsOneWidget);
    expect(find.byKey(UiTestKeys.loginPasswordField), findsOneWidget);
    expect(find.byKey(UiTestKeys.loginSubmitButton), findsOneWidget);
  });

  testWidgets('saved workout flow supports start, edit, and resume',
      (tester) async {
    final user = AppTestHarness.buildUser();
    final savedWorkout = AppTestHarness.buildWorkout(
      id: 'saved-1',
      name: 'Saved Fran',
      userId: user.id,
      type: WorkoutType.restTimer,
      intervals: const [TimerInterval(duration: 30, type: 'work')],
    );
    final harness = AppTestHarness(
      user: user,
      savedWorkouts: [savedWorkout],
    );

    await harness.pumpApp(tester);

    expect(find.byKey(UiTestKeys.dashboardSavedWorkout(savedWorkout.id)),
        findsOneWidget);

    await tester
        .tap(find.byKey(UiTestKeys.dashboardSavedWorkout(savedWorkout.id)));
    await tester.pumpAndSettle();
    expect(find.byKey(UiTestKeys.timerEditAction), findsOneWidget);

    await tester.dragFrom(const Offset(120, 300), const Offset(260, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(UiTestKeys.manualScreen), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.manualStartButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(UiTestKeys.timerPlayPauseButton), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.historyTab));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(UiTestKeys.dashboardTab));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(UiTestKeys.dashboardResumeButton), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.dashboardResumeButton));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(UiTestKeys.timerStopButton), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.timerStopButton));
    await tester.pumpAndSettle();
  });

  testWidgets('history details and delete flow work with seeded sessions',
      (tester) async {
    final user = AppTestHarness.buildUser();
    final firstSession = AppTestHarness.buildSession(
      id: 'session-1',
      userId: user.id,
      name: 'Fran',
      startedAt: DateTime.now(),
      roundsCompleted: 5,
      notes: 'Felt strong today',
    );
    final secondSession = AppTestHarness.buildSession(
      id: 'session-2',
      userId: user.id,
      name: 'Cindy',
      startedAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    final harness = AppTestHarness(
      user: user,
      savedSessions: [firstSession, secondSession],
    );

    await harness.pumpApp(tester);

    await tester.tap(find.byKey(UiTestKeys.historyTab));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(UiTestKeys.historySession(firstSession.id)));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Felt strong today'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(UiTestKeys.historySession(firstSession.id)),
      const Offset(-600, 0),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
        find.byKey(UiTestKeys.historySession(firstSession.id)), findsNothing);
    expect(harness.storage.sessions.containsKey(firstSession.id), isFalse);
  });

  testWidgets(
      'auth-gated save hides for guests and saves for authenticated users',
      (tester) async {
    final guestHarness = AppTestHarness();
    await guestHarness.pumpApp(tester);

    await tester.tap(find.byKey(UiTestKeys.manualTab));
    await tester.pumpAndSettle();
    expect(find.byKey(UiTestKeys.manualSaveButton), findsNothing);

    final user = AppTestHarness.buildUser();
    final authenticatedHarness = AppTestHarness(user: user);
    await authenticatedHarness.pumpApp(tester);

    await tester.tap(find.byKey(UiTestKeys.manualTab));
    await tester.pumpAndSettle();
    expect(find.byKey(UiTestKeys.manualSaveButton), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.manualSaveButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(UiTestKeys.saveTemplateNameField),
      'Saved Auth Timer',
    );
    await tester.tap(find.byKey(UiTestKeys.saveTemplateSubmitButton));
    await tester.pumpAndSettle();

    expect(
      authenticatedHarness.storage.workouts.values.any(
        (workout) => workout.name == 'Saved Auth Timer',
      ),
      isTrue,
    );
  });

  testWidgets(
      'saved timer appears on dashboard after save and can be drag-deleted',
      (tester) async {
    final user = AppTestHarness.buildUser();
    final harness = AppTestHarness(
      user: user,
      parseResponse:
          AppTestHarness.defaultParseResponse(input: 'Dashboard Save'),
    );
    const timerName = 'Dash Delete';

    await harness.pumpApp(tester);

    await tester.enterText(
      find.byKey(UiTestKeys.dashboardTextInput),
      'Dashboard save workout',
    );
    await tester.tap(find.byKey(UiTestKeys.dashboardCreateTimerButton));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(UiTestKeys.timerCancelButton), findsOneWidget);
    await tester.tap(find.byKey(UiTestKeys.timerCancelButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(UiTestKeys.saveTemplateNameField),
      timerName,
    );
    await tester.tap(find.byKey(UiTestKeys.saveTemplateSubmitButton));
    await tester.pump();
    await tester.pumpAndSettle();

    for (int i = 0;
        i < 20 &&
            find.byKey(UiTestKeys.saveTemplateNameField).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    for (int i = 0;
        i < 20 && find.byType(BottomSheet).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.byKey(UiTestKeys.dashboardScreen), findsOneWidget);

    for (int i = 0; i < 20 && find.text(timerName).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text(timerName), findsOneWidget);

    final cardFinder = find
        .ancestor(
          of: find.text(timerName),
          matching: find.byType(LongPressDraggable<Workout>),
        )
        .first;
    final cardCenter = tester.getCenter(cardFinder);
    final gesture = await tester.startGesture(cardCenter);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Drag here to delete'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('Drag here to delete')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text(timerName), findsNothing);
    expect(
      harness.storage.workouts.values
          .any((workout) => workout.name == timerName),
      isFalse,
    );
  });

  testWidgets(
      'video flow records with fake provider, stops, and returns to timer',
      (tester) async {
    final user = AppTestHarness.buildUser();
    final initialWorkout = AppTestHarness.buildWorkout(
      id: 'video-1',
      name: 'Video Flow',
      userId: user.id,
    );
    final harness = AppTestHarness(
      user: user,
      initialWorkout: initialWorkout,
      fromSavedWorkoutId: initialWorkout.id,
    );

    await harness.pumpApp(tester);

    await tester.tap(find.byKey(UiTestKeys.timerPlayPauseButton));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.dragFrom(const Offset(260, 300), const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(UiTestKeys.videoScreen), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.videoRecordButton));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(UiTestKeys.videoStopButton), findsOneWidget);
    expect(find.text('00:01'), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.videoStopButton));
    await tester.pumpAndSettle();
    expect(find.text('Preview ready'), findsOneWidget);

    await tester.tap(find.byKey(testPreviewCloseButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(UiTestKeys.dashboardScreen), findsOneWidget);
    expect(find.byKey(UiTestKeys.timerStopButton), findsOneWidget);

    await tester.tap(find.byKey(UiTestKeys.timerStopButton));
    await tester.pumpAndSettle();
  });
}
