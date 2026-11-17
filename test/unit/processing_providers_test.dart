import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../lib/src/api.dart';
import '../../lib/src/providers.dart';
import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeWebsparkBackend backend;
  late ProviderContainer container;

  setUp(() {
    backend = FakeWebsparkBackend();
    container = ProviderContainer(overrides: pathfinderTestOverrides(backend));
  });

  tearDown(() => container.dispose());

  test('GET fetch creates two tasks without using the network', () async {
    final List<PathTask> tasks = await container
        .read(pathTasksProvider.notifier)
        .fetch();
    expect(tasks.map((PathTask task) => task.id), <String>[
      'demo-01',
      'demo-02',
    ]);
    expect(backend.count('GET'), 1);
    expect(container.read(pathTasksProvider).requireValue, hasLength(2));
  });

  test('GET failure is recoverable on retry', () async {
    backend.failFirstGet = true;
    final Processing notifier = container.read(processingProvider.notifier);
    await notifier.start(stepDelay: Duration.zero);
    expect(
      container.read(processingProvider).status,
      ProcessingStatus.failure,
    );
    expect(
      container.read(processingProvider).errorMessage,
      contains('Simulated task fetch failure'),
    );
    expect(container.read(pathResultsProvider), isEmpty);

    await notifier.start(stepDelay: Duration.zero);
    expect(
      container.read(processingProvider).status,
      ProcessingStatus.readyToSend,
    );
    expect(backend.count('GET'), 2);
  });

  test(
    'processing produces paths and exposes exact replay counters',
    () async {
      final List<double> progressSamples = <double>[];
      final ProviderSubscription<double> listener = container.listen<double>(
        processingProgressProvider,
        (double? previous, double next) => progressSamples.add(next),
        fireImmediately: true,
      );
      addTearDown(listener.close);

      await container
          .read(processingProvider.notifier)
          .start(stepDelay: Duration.zero);
      final ProcessingState processing = container.read(processingProvider);
      final PlaybackState playback = container.read(aStarPlaybackProvider);
      final List<PathResultRequest> results = container.read(
        pathResultsProvider,
      );

      expect(processing.status, ProcessingStatus.readyToSend);
      expect(processing.completed, 2);
      expect(processing.total, 2);
      expect(container.read(processingProgressProvider), 1);
      expect(results, hasLength(2));
      expect(results.first.result.steps.first.x, 0);
      expect(results.first.result.steps.last.x, 2);
      expect(playback.operationIndex, playback.totalComputations);
      expect(playback.finished, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(progressSamples, isNotEmpty);
      expect(progressSamples.last, 1);
      expect(
        progressSamples.every((double value) => value >= 0 && value <= 1),
        isTrue,
      );
      expect(backend.count('GET'), 1);
    },
  );

  test('A* playback can pause and resume without losing the trace', () async {
    const PathTask task = PathTask(
      id: 'pause',
      field: <String>['...', '...', '...'],
      start: GridPoint(x: 0, y: 0),
      end: GridPoint(x: 2, y: 2),
    );
    final AStarPlayback playback = container.read(
      aStarPlaybackProvider.notifier,
    );
    playback.setSpeed(const Duration(milliseconds: 5));
    final Future<List<GridPoint>> run = playback.play(task);
    playback.pause();
    expect(container.read(aStarPlaybackProvider).paused, isTrue);
    expect(container.read(aStarPlaybackProvider).running, isTrue);
    playback.resume();
    final List<GridPoint> path = await run;
    expect(path.first.x, 0);
    expect(path.last.x, 2);
    expect(container.read(aStarPlaybackProvider).finished, isTrue);
    expect(container.read(aStarPlaybackProvider).progress, 1);
  });

  test(
    'POST sends the computed results and stores server verifications',
    () async {
      final Processing notifier = container.read(processingProvider.notifier);
      await notifier.start(stepDelay: Duration.zero);
      await notifier.sendResults();

      expect(
        container.read(processingProvider).status,
        ProcessingStatus.success,
      );
      expect(backend.count('POST'), 1);
      expect(backend.lastPostedBody, isA<List<dynamic>>());
      expect(backend.lastPostedBody! as List<dynamic>, hasLength(2));
      expect(
        container.read(resultsSubmissionProvider).status,
        SubmissionStatus.success,
      );
      expect(
        container.read(resultsSubmissionProvider).verifications,
        hasLength(2),
      );
      expect(
        container
            .read(resultsSubmissionProvider)
            .verifications
            .every((PathVerification verification) => verification.correct),
        isTrue,
      );
    },
  );

  test('failed POST does not drop paths and retry succeeds', () async {
    backend.failFirstPost = true;
    final Processing notifier = container.read(processingProvider.notifier);
    await notifier.start(stepDelay: Duration.zero);
    await notifier.sendResults();

    expect(
      container.read(processingProvider).status,
      ProcessingStatus.readyToSend,
    );
    expect(
      container.read(processingProvider).errorMessage,
      contains('Simulated submission failure'),
    );
    expect(container.read(pathResultsProvider), hasLength(2));
    expect(
      container.read(resultsSubmissionProvider).status,
      SubmissionStatus.failure,
    );

    await notifier.retrySending();
    expect(
      container.read(processingProvider).status,
      ProcessingStatus.success,
    );
    expect(backend.count('POST'), 2);
  });

  test('reset clears stale trace, results, and workflow state', () async {
    final Processing notifier = container.read(processingProvider.notifier);
    await notifier.start(stepDelay: Duration.zero);
    notifier.reset();

    expect(
      container.read(processingProvider).status,
      ProcessingStatus.initial,
    );
    expect(container.read(pathResultsProvider), isEmpty);
    expect(container.read(aStarPlaybackProvider).task, isNull);
    expect(container.read(pathTasksProvider).requireValue, isEmpty);
    expect(
      container.read(resultsSubmissionProvider).status,
      SubmissionStatus.idle,
    );
  });
}
