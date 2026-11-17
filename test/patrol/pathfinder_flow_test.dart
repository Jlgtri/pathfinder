/// Deterministic Patrol E2E tests; no live API calls or credentials required.
/// Configure `patrol.test_directory: tests/patrol` in pubspec.yaml.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pathfinder/src/providers.dart';
import 'package:patrol/patrol.dart';

import '../support/test_app.dart';

void main() {
  patrolTest('configure → calculate → submit → result details → back', (
    PatrolIntegrationTester $,
  ) async {
    final TestPathfinderApp app = TestPathfinderApp(FakeWebsparkBackend());
    addTearDown(app.dispose);
    await app.initialize();
    await $.pumpWidgetAndSettle(app.widget);

    expect(find.text('Configure your workspace'), findsOneWidget);
    await $(find.byTooltip('Switch to dark mode')).tap();
    expect(find.byTooltip('Switch to light mode'), findsOneWidget);

    // A valid endpoint is already provided by TestEndpointUrlNotifier.
    await $('Start Calculation').tap();
    await $.tester.runAsync(() async {
      final Stopwatch timeout = Stopwatch()..start();
      while (app.container.read(processingProvider).status !=
          ProcessingStatus.calculating) {
        if (timeout.elapsed > const Duration(seconds: 10)) {
          throw StateError('A* playback did not start');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await $.tester.pump();
    await $.tester.ensureVisible(find.text('MAX'));
    await $('MAX').tap();
    await $('Send Results to Server').tap();
    await $('Path Result 01').tap();

    expect(find.text('Shortest Path'), findsOneWidget);
    expect(find.text('Route Coordinates'), findsOneWidget);
    expect(find.textContaining('COORDINATE MATRIX'), findsOneWidget);

    await $(find.byTooltip('Back')).tap();
    expect(find.text('Your calculated paths'), findsOneWidget);
  });

  patrolTest('shows submission failure and retries without recalculation', (
    PatrolIntegrationTester $,
  ) async {
    final FakeWebsparkBackend backend = FakeWebsparkBackend(
      failFirstPost: true,
    );
    final TestPathfinderApp app = TestPathfinderApp(backend);
    addTearDown(app.dispose);
    await app.initialize();
    await $.pumpWidgetAndSettle(app.widget);

    await $('Start Calculation').tap();
    await $.tester.runAsync(() async {
      final Stopwatch timeout = Stopwatch()..start();
      while (app.container.read(processingProvider).status !=
          ProcessingStatus.calculating) {
        if (timeout.elapsed > const Duration(seconds: 10)) {
          throw StateError('A* playback did not start');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await $.tester.pump();
    await $.tester.ensureVisible(find.text('MAX'));
    await $('MAX').tap();
    await $('Send Results to Server').tap();
    expect(find.textContaining('Simulated submission failure'), findsWidgets);
    await $('Retry Sending').tap();
    expect(find.text('Your calculated paths'), findsOneWidget);
    expect(backend.count('GET'), 1);
    expect(backend.count('POST'), 2);
  });
}
