part of '../providers.dart';

// 1. API task loading ---------------------------------------------------------

@Riverpod(keepAlive: true, dependencies: <Object>[api])
class PathTasks extends _$PathTasks {
  int _generation = 0;

  @override
  Future<List<PathTask>> build() async => const <PathTask>[];

  Future<List<PathTask>> fetch() async {
    final int generation = ++_generation;
    state = const AsyncLoading<List<PathTask>>();

    try {
      final API? client = await ref.read(apiProvider.future);
      if (client == null) throw StateError('API endpoint is not configured');

      final PathTasksResponse response = await client.getTasks();
      if (response.error) throw StateError(response.message);
      if (response.data.isEmpty) throw StateError('No tasks received');

      final List<PathTask> tasks = List<PathTask>.unmodifiable(response.data);
      if (ref.mounted && generation == _generation) {
        state = AsyncData<List<PathTask>>(tasks);
      }
      return tasks;
    } catch (error, stack) {
      if (ref.mounted && generation == _generation) {
        state = AsyncError<List<PathTask>>(error, stack);
      }
      rethrow;
    }
  }

  void clear() {
    ++_generation;
    state = const AsyncData<List<PathTask>>(<PathTask>[]);
  }
}

// 2. Completed results --------------------------------------------------------

@Riverpod(keepAlive: true)
class PathResults extends _$PathResults {
  @override
  List<PathResultRequest> build() => const <PathResultRequest>[];

  void add(PathResultRequest result) =>
      state = List<PathResultRequest>.unmodifiable(<PathResultRequest>[
        ...state,
        result,
      ]);

  void clear() => state = const <PathResultRequest>[];
}

// 3. A* slow-motion playback --------------------------------------------------

@Riverpod(keepAlive: true)
AStarTraceSolver aStarTraceSolver(Ref ref) => const AStarTraceSolver();

final class PlaybackState {
  const new({
    this.task,
    this.operation,
    this.operationIndex = 0,
    this.totalComputations = 0,
    this.walkableCells = 0,
    this.running = false,
    this.paused = false,
    this.finished = false,
    this.expandedCells = const <int>{},
    this.path = const <GridPoint>[],
  });

  final PathTask? task;
  final AStarTraceEntry? operation;

  /// 1-based index of the operation displayed in the UI.
  final int operationIndex;
  final int totalComputations;
  final int walkableCells;
  final bool running;
  final bool paused;
  final bool finished;

  /// Coordinates encoded as y * gridSize + x for efficient grid rendering.
  final Set<int> expandedCells;
  final List<GridPoint> path;

  double get progress =>
      totalComputations == 0 ? 0 : operationIndex / totalComputations;

  GridPoint? get current => operation?.current;
  GridPoint? get candidate => operation?.candidate;
  bool get accepted => operation?.accepted ?? false;
  int get expanded => operation?.expanded ?? 0;
  int get inspected => operation?.inspected ?? 0;
  int get improved => operation?.improved ?? 0;
  int get frontierSize => operation?.frontierSize ?? 0;
  int? get g => operation?.g;
  int? get h => operation?.h;
  int? get f => operation?.f;
}

@Riverpod(keepAlive: true, dependencies: <Object>[aStarTraceSolver])
class AStarPlayback extends _$AStarPlayback {
  int _version = 0;
  bool _paused = false;
  Completer<void>? _continue;
  Duration _delay = const Duration(milliseconds: 40);

  @override
  PlaybackState build() => const PlaybackState();

  void setSpeed(Duration delay) {
    if (delay.isNegative) throw ArgumentError.value(delay, 'delay');
    _delay = delay;
  }

  Future<List<GridPoint>> play(PathTask task) async {
    cancel();
    final int version = _version;
    final AStarTraceResult trace = ref
        .read(aStarTraceSolverProvider)
        .trace(task);
    final Set<int> expandedCells = <int>{};
    Set<int> expandedSnapshot = const <int>{};
    final int size = task.field.length;

    state = PlaybackState(
      task: task,
      totalComputations: trace.totalComputations,
      walkableCells: trace.walkableCells,
      running: true,
    );

    for (int i = 0; i < trace.operations.length; i++) {
      await _waitIfPaused();
      if (!ref.mounted || version != _version) {
        throw StateError('A* playback cancelled');
      }

      final AStarTraceEntry operation = trace.operations[i];
      if (operation.kind == AStarOperation.expand) {
        expandedCells.add(operation.current.y * size + operation.current.x);
        expandedSnapshot = Set<int>.unmodifiable(expandedCells);
      }

      state = PlaybackState(
        task: task,
        operation: operation,
        operationIndex: i + 1,
        totalComputations: trace.totalComputations,
        walkableCells: trace.walkableCells,
        running: true,
        expandedCells: expandedSnapshot,
      );

      if (_delay > Duration.zero) {
        await Future<void>.delayed(_delay);
      } else if (i % 64 == 0) {
        // Even at maximum speed, yield occasionally on Flutter Web.
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (!ref.mounted || version != _version) {
      throw StateError('A* playback cancelled');
    }

    final PlaybackState previous = state;
    state = PlaybackState(
      task: task,
      operation: previous.operation,
      operationIndex: previous.operationIndex,
      totalComputations: previous.totalComputations,
      walkableCells: previous.walkableCells,
      expandedCells: previous.expandedCells,
      path: trace.path,
      finished: true,
    );
    return trace.path;
  }

  void pause() {
    if (!state.running || _paused) return;
    _paused = true;
    _continue = Completer<void>();
    final PlaybackState previous = state;
    state = PlaybackState(
      task: previous.task,
      operation: previous.operation,
      operationIndex: previous.operationIndex,
      totalComputations: previous.totalComputations,
      walkableCells: previous.walkableCells,
      expandedCells: previous.expandedCells,
      path: previous.path,
      running: true,
      paused: true,
    );
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    final Completer<void>? waiter = _continue;
    _continue = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
    final PlaybackState previous = state;
    state = PlaybackState(
      task: previous.task,
      operation: previous.operation,
      operationIndex: previous.operationIndex,
      totalComputations: previous.totalComputations,
      walkableCells: previous.walkableCells,
      expandedCells: previous.expandedCells,
      path: previous.path,
      running: true,
    );
  }

  Future<void> _waitIfPaused() async {
    while (_paused) {
      final Completer<void>? waiter = _continue;
      if (waiter == null) break;
      await waiter.future;
    }
  }

  void cancel() {
    _version++;
    _paused = false;
    final Completer<void>? waiter = _continue;
    _continue = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
    state = const PlaybackState();
  }
}

// 4. Server result submission -------------------------------------------------

enum SubmissionStatus { idle, sending, success, failure }

final class SubmissionState {
  const new({
    this.status = SubmissionStatus.idle,
    this.verifications = const <PathVerification>[],
    this.errorMessage,
  });

  final SubmissionStatus status;
  final List<PathVerification> verifications;
  final String? errorMessage;
}

@Riverpod(keepAlive: true, dependencies: <Object>[api, PathResults])
class ResultsSubmission extends _$ResultsSubmission {
  bool _busy = false;
  int _generation = 0;

  @override
  SubmissionState build() => const SubmissionState();

  Future<void> send() async {
    if (_busy) throw StateError('Submission already running');
    _busy = true;
    final int generation = ++_generation;
    state = const SubmissionState(status: SubmissionStatus.sending);

    try {
      final API? client = await ref.read(apiProvider.future);
      if (client == null) throw StateError('API endpoint is not configured');

      final List<PathResultRequest> results = ref.read(pathResultsProvider);
      if (results.isEmpty) throw StateError('No results to submit');

      // If the new Retrofit mixin takes one argument, remove the empty map.
      // If it uses @Queries, forward saved query parameters instead.
      final SubmitResultsResponse response = await client.sendResults(
        results,
        const <String, dynamic>{},
      );
      if (!ref.mounted || generation != _generation) return;
      if (response.error) throw StateError(response.message);

      state = SubmissionState(
        status: SubmissionStatus.success,
        verifications: List<PathVerification>.unmodifiable(response.data),
      );
    } catch (error) {
      if (ref.mounted && generation == _generation) {
        state = SubmissionState(
          status: SubmissionStatus.failure,
          errorMessage: error.toString(),
        );
      }
      rethrow;
    } finally {
      if (generation == _generation) _busy = false;
    }
  }

  void reset() {
    ++_generation;
    _busy = false;
    state = const SubmissionState();
  }
}

// 5. Lightweight workflow coordinator ---------------------------------------

enum ProcessingStatus {
  initial,
  loading,
  calculating,
  paused,
  readyToSend,
  sending,
  success,
  failure,
}

final class ProcessingState {
  const new({
    this.status = ProcessingStatus.initial,
    this.completed = 0,
    this.total = 0,
    this.currentTaskIndex,
    this.currentTaskId,
    this.errorMessage,
  });

  final ProcessingStatus status;
  final int completed;
  final int total;
  final int? currentTaskIndex; // zero-based
  final String? currentTaskId;
  final String? errorMessage;

  double get progress => total == 0 ? 0 : completed / total;
  bool get canSend => status == ProcessingStatus.readyToSend;
}

@Riverpod(
  keepAlive: true,
  dependencies: <Object>[
    PathTasks,
    PathResults,
    AStarPlayback,
    ResultsSubmission,
  ],
)
class Processing extends _$Processing {
  bool _busy = false;
  int _version = 0;

  @override
  ProcessingState build() => const ProcessingState();

  Future<void> start({
    Duration stepDelay = const Duration(milliseconds: 40),
  }) async {
    if (_busy) return;
    _busy = true;
    final int version = ++_version;

    ref.read(aStarPlaybackProvider.notifier).cancel();
    ref.read(aStarPlaybackProvider.notifier).setSpeed(stepDelay);
    ref.read(pathResultsProvider.notifier).clear();
    ref.read(resultsSubmissionProvider.notifier).reset();
    state = const ProcessingState(status: ProcessingStatus.loading);

    try {
      final List<PathTask> tasks = await ref
          .read(pathTasksProvider.notifier)
          .fetch();
      if (!ref.mounted || version != _version) return;

      state = ProcessingState(
        status: ProcessingStatus.calculating,
        total: tasks.length,
      );

      for (int i = 0; i < tasks.length; i++) {
        if (!ref.mounted || version != _version) return;
        final PathTask task = tasks[i];

        state = ProcessingState(
          status: ProcessingStatus.calculating,
          total: tasks.length,
          completed: i,
          currentTaskIndex: i,
          currentTaskId: task.id,
        );

        final List<GridPoint> steps = await ref
            .read(aStarPlaybackProvider.notifier)
            .play(task);
        if (!ref.mounted || version != _version) return;

        final String path = steps
            .map((GridPoint point) => '(${point.x},${point.y})')
            .join('->');
        ref
            .read(pathResultsProvider.notifier)
            .add(
              PathResultRequest(
                id: task.id,
                result: PathResultData(steps: steps, path: path),
              ),
            );

        state = ProcessingState(
          status: i == tasks.length - 1
              ? ProcessingStatus.readyToSend
              : ProcessingStatus.calculating,
          total: tasks.length,
          completed: i + 1,
          currentTaskIndex: i,
          currentTaskId: task.id,
        );
      }
    } catch (error) {
      if (!ref.mounted || version != _version) return;
      final ProcessingState previous = state;
      state = ProcessingState(
        status: ProcessingStatus.failure,
        completed: previous.completed,
        total: previous.total,
        currentTaskIndex: previous.currentTaskIndex,
        currentTaskId: previous.currentTaskId,
        errorMessage: error.toString(),
      );
    } finally {
      if (version == _version) _busy = false;
    }
  }

  void pause() {
    if (state.status != ProcessingStatus.calculating) return;
    ref.read(aStarPlaybackProvider.notifier).pause();
    final ProcessingState previous = state;
    state = ProcessingState(
      status: ProcessingStatus.paused,
      completed: previous.completed,
      total: previous.total,
      currentTaskIndex: previous.currentTaskIndex,
      currentTaskId: previous.currentTaskId,
    );
  }

  void resume() {
    if (state.status != ProcessingStatus.paused) return;
    ref.read(aStarPlaybackProvider.notifier).resume();
    final ProcessingState previous = state;
    state = ProcessingState(
      status: ProcessingStatus.calculating,
      completed: previous.completed,
      total: previous.total,
      currentTaskIndex: previous.currentTaskIndex,
      currentTaskId: previous.currentTaskId,
    );
  }

  void setSpeed(Duration delay) =>
      ref.read(aStarPlaybackProvider.notifier).setSpeed(delay);

  Future<void> sendResults() async {
    if (_busy || !state.canSend) return;
    _busy = true;
    final int version = _version;
    final ProcessingState previous = state;

    state = ProcessingState(
      status: ProcessingStatus.sending,
      completed: previous.completed,
      total: previous.total,
      currentTaskIndex: previous.currentTaskIndex,
      currentTaskId: previous.currentTaskId,
    );

    try {
      await ref.read(resultsSubmissionProvider.notifier).send();
      if (!ref.mounted || version != _version) return;
      state = ProcessingState(
        status: ProcessingStatus.success,
        completed: previous.completed,
        total: previous.total,
        currentTaskIndex: previous.currentTaskIndex,
        currentTaskId: previous.currentTaskId,
      );
    } catch (error) {
      if (!ref.mounted || version != _version) return;
      state = ProcessingState(
        status: ProcessingStatus.readyToSend,
        completed: previous.completed,
        total: previous.total,
        currentTaskIndex: previous.currentTaskIndex,
        currentTaskId: previous.currentTaskId,
        errorMessage: error.toString(),
      );
    } finally {
      if (version == _version) _busy = false;
    }
  }

  Future<void> refresh() => start();
  Future<void> retrySending() => sendResults();

  void reset() {
    ++_version;
    _busy = false;
    ref.read(aStarPlaybackProvider.notifier).cancel();
    ref.read(pathResultsProvider.notifier).clear();
    ref.read(pathTasksProvider.notifier).clear();
    ref.read(resultsSubmissionProvider.notifier).reset();
    state = const ProcessingState();
  }
}

/// Combined progress, including the current task's A* replay fraction.
@Riverpod(keepAlive: true, dependencies: <Object>[Processing, AStarPlayback])
double processingProgress(Ref ref) {
  final ProcessingState run = ref.watch(processingProvider);
  final PlaybackState playback = ref.watch(aStarPlaybackProvider);
  if (run.total == 0) return 0;

  final bool isActive =
      run.status == ProcessingStatus.calculating ||
      run.status == ProcessingStatus.paused;
  return (run.completed + (isActive ? playback.progress : 0.0)) / run.total;
}
