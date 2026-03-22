import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ai_wod_timer/widgets/report_problem_modal.dart';
import 'package:ai_wod_timer/services/report_service.dart';
import 'package:ai_wod_timer/theme/app_theme.dart';

Widget _buildTestApp({required Widget child}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: child),
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
  });

  group('ReportProblemModal', () {
    testWidgets('shows all category chips', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ReportProblemModal.show(
                  context: context,
                  originalParsed: {'type': 'amrap'},
                  appVersion: '1.0.0+1',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify all category chips are shown
      for (final kind in ReportKind.values) {
        expect(find.text(kind.displayLabel), findsOneWidget);
      }
    });

    testWidgets('submit button is disabled until category is selected',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ReportProblemModal.show(
                  context: context,
                  originalParsed: {'type': 'amrap'},
                  appVersion: '1.0.0+1',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Find submit button
      final submitButton = find.widgetWithText(ElevatedButton, 'Submit Report');
      expect(submitButton, findsOneWidget);

      // Button should be disabled (onPressed is null)
      final ElevatedButton button = tester.widget(submitButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('submit button is enabled after selecting category',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ReportProblemModal.show(
                  context: context,
                  originalParsed: {'type': 'amrap'},
                  appVersion: '1.0.0+1',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Select a category
      await tester.tap(find.text('Wrong workout type'));
      await tester.pumpAndSettle();

      // Submit button should now be enabled
      final submitButton = find.widgetWithText(ElevatedButton, 'Submit Report');
      final ElevatedButton button = tester.widget(submitButton);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows optional details text field', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ReportProblemModal.show(
                  context: context,
                  originalParsed: {'type': 'amrap'},
                  appVersion: '1.0.0+1',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Details text field should be present
      expect(find.text('DETAILS (optional)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('can close modal with X button', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ReportProblemModal.show(
                  context: context,
                  originalParsed: {'type': 'amrap'},
                  appVersion: '1.0.0+1',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Modal should be open
      expect(find.text('Report a problem'), findsOneWidget);

      // Close the modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Modal should be closed
      expect(find.text('Report a problem'), findsNothing);
    });

    testWidgets('deselecting category disables submit button', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ReportProblemModal.show(
                  context: context,
                  originalParsed: {'type': 'amrap'},
                  appVersion: '1.0.0+1',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Select a category
      await tester.tap(find.text('Wrong intervals'));
      await tester.pumpAndSettle();

      // Button should be enabled
      var submitButton = find.widgetWithText(ElevatedButton, 'Submit Report');
      var button = tester.widget<ElevatedButton>(submitButton);
      expect(button.onPressed, isNotNull);

      // Deselect the category (tap again)
      await tester.tap(find.text('Wrong intervals'));
      await tester.pumpAndSettle();

      // Button should be disabled again
      submitButton = find.widgetWithText(ElevatedButton, 'Submit Report');
      button = tester.widget<ElevatedButton>(submitButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('displays section header', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ReportProblemModal.show(
                  context: context,
                  originalParsed: {'type': 'amrap'},
                  appVersion: '1.0.0+1',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('WHAT WENT WRONG?'), findsOneWidget);
    });
  });
}
