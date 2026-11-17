import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mix/mix.dart';

import '../api.dart';
import '../providers.dart';
import '../routes.dart';
import '../styles.dart';
import '../widgets/route_header.dart';

part 'route_02_processing.g.dart';

/// Shows the current task, recorded A* search and result submission.
@TypedGoRoute<ProcessingRoute>(path: '/processing')
class ProcessingRoute extends GoRouteData with $ProcessingRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      state.extra is ProcessingScreen
      ? state.extra! as ProcessingScreen
      : const ProcessingScreen();

  @override
  CustomTransitionPage<void> buildPage(
    BuildContext context,
    GoRouterState state,
  ) => CustomTransitionPage<void>(
    key: state.pageKey,
    child: build(context, state),
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) => FadeTransition(opacity: animation, child: child),
  );
}

extension on ProcessingStatus {
  String get title => switch (this) {
    ProcessingStatus.loading => 'Loading tasks...',
    ProcessingStatus.readyToSend ||
    ProcessingStatus.success => 'All calculations completed',
    ProcessingStatus.sending => 'Sending results to server',
    ProcessingStatus.paused => 'Calculation paused',
    ProcessingStatus.failure => 'Calculation failed',
    _ => 'Calculating shortest paths',
  };

  String get subtitle => switch (this) {
    ProcessingStatus.loading => 'Fetching grid tasks from the server...',
    ProcessingStatus.readyToSend || ProcessingStatus.success =>
      'Your shortest paths are ready to be submitted.',
    ProcessingStatus.sending => 'Uploading your calculated routes.',
    ProcessingStatus.paused =>
      'The A* search visualization is paused. Resume at any time.',
    ProcessingStatus.failure =>
      'Something went wrong while processing your tasks.',
    _ =>
      "We're processing your grid tasks and finding the "
          'most efficient routes.',
  };

  String get message => switch (this) {
    ProcessingStatus.initial => 'Preparing calculation...',
    ProcessingStatus.loading => 'Fetching grid tasks...',
    ProcessingStatus.calculating => 'Finding optimal routes...',
    ProcessingStatus.paused => 'A* playback paused',
    ProcessingStatus.readyToSend => 'All optimal routes are ready.',
    ProcessingStatus.sending => 'Sending calculated paths...',
    ProcessingStatus.success => 'Results successfully submitted.',
    ProcessingStatus.failure => 'Unable to finish calculation.',
  };

  String get statusLabel => switch (this) {
    ProcessingStatus.initial => 'Waiting',
    ProcessingStatus.loading => 'Loading',
    ProcessingStatus.calculating => 'Calculating',
    ProcessingStatus.paused => 'Paused',
    ProcessingStatus.readyToSend => 'Ready',
    ProcessingStatus.sending => 'Uploading',
    ProcessingStatus.success => 'Completed',
    ProcessingStatus.failure => 'Failed',
  };

  String processingLabel({required bool retryingSubmission}) => switch (this) {
    ProcessingStatus.initial => 'Waiting for Tasks...',
    ProcessingStatus.loading => 'Loading Tasks...',
    ProcessingStatus.calculating => 'Calculating Matrix...',
    ProcessingStatus.paused => 'Calculation Paused',
    ProcessingStatus.readyToSend =>
      retryingSubmission ? 'Retry Sending' : 'Send Results to Server',
    ProcessingStatus.sending => 'Sending Results...',
    ProcessingStatus.success => 'View Results',
    ProcessingStatus.failure => 'Retry Calculation',
  };
}

/// Connects the existing Mix screen to the split Riverpod state providers.
class ProcessingScreen extends HookConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The coordinator is synchronous now (not AsyncValue<ProcessingState>).
    ref.listen<ProcessingState>(processingProvider, (
      ProcessingState? previous,
      ProcessingState next,
    ) {
      if (previous?.status == ProcessingStatus.success ||
          next.status != ProcessingStatus.success) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Routes.results.go(GoRouter.of(context));
        }
      });
    });

    final ProcessingState run = ref.watch(processingProvider);
    final PlaybackState playback = ref.watch(aStarPlaybackProvider);
    final AsyncValue<List<PathTask>> tasks = ref.watch(pathTasksProvider);
    final List<PathResultRequest> results = ref.watch(pathResultsProvider);
    final SubmissionState submission = ref.watch(resultsSubmissionProvider);
    final double progress = ref
        .watch(processingProgressProvider)
        .clamp(0.0, 1.0);
    final ProcessingStatus status = run.status;
    final ValueNotifier<int> speedNotifier = useState<int>(1000);

    final String? error =
        run.errorMessage ??
        submission.errorMessage ??
        (tasks.hasError ? tasks.error.toString() : null);

    // Start exactly once when entering an idle screen. Never restart the
    // calculation on every animation frame or after returning from Details.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (ref.read(processingProvider).status == ProcessingStatus.initial) {
          unawaited(
            ref
                .read(processingProvider.notifier)
                .start(stepDelay: Duration(milliseconds: speedNotifier.value)),
          );
        }
      });
      return null;
    }, const <Object>[]);

    final bool canControlPlayback =
        status == ProcessingStatus.calculating ||
        status == ProcessingStatus.paused;

    return BoxStyler()
        .alignment(
          defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS
              ? .topCenter
              : .center,
        )
        .color($Colors.background())(
      child: SafeArea(
        child: SingleChildScrollView(
          child:
              FlexBoxStyler()
                  .column()
                  .crossAxisAlignment(.stretch)
                  .maxWidth(460)
                  .wrap(.box(BoxStyler().alignment(.center)))
                  .paddingX($Spaces.md())
                  .paddingTop($Spaces.sm())
                  .paddingBottom($Spaces.xxl())(
                children: <Widget>[
                  RouteHeader(
                    isDark:
                        ref.watch(themeProvider).asData?.value == Themes.dark,
                    onToggleTheme: () {
                      ref.read(themeProvider.notifier).toggle();
                    },
                    onBack: status == ProcessingStatus.sending
                        ? null
                        : () {
                            ref.read(processingProvider.notifier).reset();
                            Routes.configuration.go(GoRouter.of(context));
                          },
                  ),
                  BoxStyler().height($Spaces.sm())(),
                  FlexBoxStyler()
                      .column()
                      .crossAxisAlignment(.center)
                      .spacing($Spaces.xs())(
                    children: <Widget>[
                      TextStyler().style($TextStyles.h3()).textAlign(.center)(
                        status.title,
                      ),
                      TextStyler()
                          .style($TextStyles.description())
                          .textAlign(.center)(status.subtitle),
                    ],
                  ),
                  BoxStyler().height(36)(),
                  _ProgressRing(progress: progress, status: status),
                  BoxStyler().height(36)(),
                  _StatusCard(
                    status: status,
                    progress: progress,
                    completed: run.completed,
                    total: run.total,
                    resultsCount: results.length,
                  ),
                  if ((tasks.hasValue && tasks.value!.isNotEmpty) ||
                      playback.task != null) ...<Widget>[
                    BoxStyler().height($Spaces.md())(),
                    _PlaybackCard(
                      run: run,
                      playback: playback,
                      speedMilliseconds: speedNotifier.value,
                      canControlPlayback: canControlPlayback,
                      onTogglePause: () {
                        final Processing notifier = ref.read(
                          processingProvider.notifier,
                        );
                        if (status == ProcessingStatus.paused) {
                          notifier.resume();
                        } else {
                          notifier.pause();
                        }
                      },
                      onChangeSpeed: (int milliseconds) {
                        speedNotifier.value = milliseconds;
                        ref
                            .read(processingProvider.notifier)
                            .setSpeed(Duration(milliseconds: milliseconds));
                      },
                    ),
                  ],
                  if (error != null && error.isNotEmpty) ...<Widget>[
                    BoxStyler().height($Spaces.sm())(),
                    _ErrorNotice(message: error),
                  ],
                  BoxStyler().height($Spaces.lg())(),
                  _ProcessingAction(
                    status: status,
                    retryingSubmission:
                        status == ProcessingStatus.readyToSend &&
                        error != null &&
                        error.isNotEmpty,
                    onPressed: () {
                      final Processing notifier = ref.read(
                        processingProvider.notifier,
                      );
                      if (status == ProcessingStatus.failure) {
                        unawaited(
                          notifier.start(
                            stepDelay: Duration(
                              milliseconds: speedNotifier.value,
                            ),
                          ),
                        );
                      } else if (status == ProcessingStatus.readyToSend) {
                        unawaited(notifier.sendResults());
                      } else if (status == ProcessingStatus.success) {
                        Routes.results.go(GoRouter.of(context));
                      }
                    },
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const new({required this.progress, required this.status});

  final double progress;
  final ProcessingStatus status;

  @override
  Widget build(BuildContext context) {
    final bool indeterminate =
        status == ProcessingStatus.initial ||
        status == ProcessingStatus.loading;

    return BoxStyler().alignment(.center)(
      child: StackBoxStyler().alignment(.center)(
        children: <Widget>[
          BoxStyler().size(164, 164)(
            child: CircularProgressIndicator(
              value: indeterminate ? null : progress,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: $Colors.gridBackground.resolve(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                $Colors.primary.resolve(context),
              ),
            ),
          ),
          BoxStyler().size(164, 164).alignment(.center)(
            child:
                FlexBoxStyler()
                    .column()
                    .mainAxisSize(.min)
                    .crossAxisAlignment(.center)
                    .spacing($Spaces.xxs())(
                  children: <Widget>[
                    TextStyler()
                        .style($TextStyles.h2())
                        .fontSize(27)
                        .textAlign(.center)('${(progress * 100).round()}%'),
                    TextStyler()
                        .style($TextStyles.monoLabel())
                        .fontSize(10)
                        .textAlign(.center)
                        .color($Colors.textSecondary())(
                      'CALCULATION PROGRESS',
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('progress', progress));
    properties.add(EnumProperty<ProcessingStatus>('status', status));
  }
}

class _StatusCard extends StatelessWidget {
  const new({
    required this.status,
    required this.progress,
    required this.completed,
    required this.total,
    required this.resultsCount,
  });

  final ProcessingStatus status;
  final double progress;
  final int completed;
  final int total;
  final int resultsCount;

  @override
  Widget build(BuildContext context) => $Styles.card(
    child:
        FlexBoxStyler()
            .column()
            .crossAxisAlignment(.stretch)
            .spacing($Spaces.sm())(
          children: <Widget>[
            FlexBoxStyler()
                .row()
                .mainAxisAlignment(.spaceBetween)
                .crossAxisAlignment(.center)(
              children: <Widget>[
                TextStyler().style($TextStyles.smallLabel())('Status'),
                _StatusBadge(status: status),
              ],
            ),
            $Styles.stats(
              child: FlexBoxStyler().row().crossAxisAlignment(.center)(
                children: <Widget>[
                  BoxStyler().wrap(.flexible(flex: 1))(
                    child: _Statistic(
                      label: 'TASKS PROCESSED',
                      value: '$completed / $total',
                    ),
                  ),
                  BoxStyler().wrap(.flexible(flex: 1))(
                    child: const _Statistic(
                      label: 'ACTIVE ALGORITHM',
                      value: 'A* Heuristic',
                      accent: true,
                    ),
                  ),
                ],
              ),
            ),
            FlexBoxStyler()
                .column()
                .crossAxisAlignment(.stretch)
                .spacing($Spaces.xxs())(
              children: <Widget>[
                FlexBoxStyler().row().mainAxisAlignment(.spaceBetween)(
                  children: <Widget>[
                    TextStyler().style($TextStyles.smallLabel())(
                      status.message,
                    ),
                    TextStyler().style($TextStyles.monoLabel())(
                      '${(progress * 100).round()}%',
                    ),
                  ],
                ),
                _LinearProgress(progress: progress),
              ],
            ),
            TextStyler().style($TextStyles.smallLabel())(
              'Calculated paths: $resultsCount',
            ),
          ],
        ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<ProcessingStatus>('status', status));
    properties.add(DoubleProperty('progress', progress));
    properties.add(IntProperty('completed', completed));
    properties.add(IntProperty('total', total));
    properties.add(IntProperty('resultsCount', resultsCount));
  }
}

class _PlaybackCard extends StatelessWidget {
  const new({
    required this.run,
    required this.playback,
    required this.speedMilliseconds,
    required this.canControlPlayback,
    required this.onTogglePause,
    required this.onChangeSpeed,
  });

  final ProcessingState run;
  final PlaybackState playback;
  final int speedMilliseconds;
  final bool canControlPlayback;
  final VoidCallback onTogglePause;
  final ValueChanged<int> onChangeSpeed;

  String _point(GridPoint? point) =>
      point == null ? '—' : '(${point.x}, ${point.y})';

  @override
  Widget build(BuildContext context) {
    final bool isPaused = run.status == ProcessingStatus.paused;
    final bool hasTask = playback.task != null;
    final int taskNumber = (run.currentTaskIndex ?? 0) + 1;
    final String taskLabel = hasTask
        ? 'Task $taskNumber / ${run.total}  ·  ${run.currentTaskId ?? ''}'
        : 'Preparing A* trace';

    return $Styles.card(
      child:
          FlexBoxStyler()
              .column()
              .crossAxisAlignment(.stretch)
              .spacing($Spaces.sm())(
            children: <Widget>[
              FlexBoxStyler().row().mainAxisAlignment(.spaceBetween)(
                children: <Widget>[
                  TextStyler().style($TextStyles.counter())('A* Trace Replay'),
                  TextStyler()
                      .style($TextStyles.monoLabel())
                      .color($Colors.primary())(
                    isPaused
                        ? 'PAUSED'
                        : playback.finished
                        ? 'COMPLETE'
                        : 'PLAYING',
                  ),
                ],
              ),
              TextStyler().style($TextStyles.smallLabel())(taskLabel),
              FlexBoxStyler().row().mainAxisAlignment(.spaceBetween)(
                children: <Widget>[
                  TextStyler().style($TextStyles.smallLabel())(
                    'Current computation',
                  ),
                  TextStyler().style($TextStyles.counter())(
                    '${playback.operationIndex} / ${playback.totalComputations}',
                  ),
                ],
              ),
              _LinearProgress(progress: playback.progress.clamp(0.0, 1.0)),
              if (hasTask) ...<Widget>[
                BoxStyler().height($Spaces.xs())(),
                _TraceGrid(playback: playback),
                FlexBoxStyler().row().mainAxisAlignment(.spaceBetween)(
                  children: <Widget>[
                    _Statistic(
                      label: 'CURRENT NODE',
                      value: _point(playback.current),
                    ),
                    _Statistic(
                      label: 'INSPECTED',
                      value: _point(playback.candidate),
                    ),
                  ],
                ),
                TextStyler().style($TextStyles.smallLabel())(
                  playback.operation == null
                      ? 'Preparing search...'
                      : playback.candidate == null
                      ? 'Expanding node ${_point(playback.current)}'
                      : playback.accepted
                      ? 'Candidate accepted / path improved'
                      : 'Candidate inspected / not improved',
                ),
                $Styles.stats(
                  child:
                      FlexBoxStyler().row().mainAxisAlignment(.spaceBetween)(
                        children: <Widget>[
                          _CompactValue('EXPANDED', '${playback.expanded}'),
                          _CompactValue('CHECKED', '${playback.inspected}'),
                          _CompactValue(
                            'FRONTIER',
                            '${playback.frontierSize}',
                          ),
                        ],
                      ),
                ),
                $Styles.stats(
                  child:
                      FlexBoxStyler().row().mainAxisAlignment(.spaceBetween)(
                        children: <Widget>[
                          _CompactValue('G', '${playback.g ?? '—'}'),
                          _CompactValue('H', '${playback.h ?? '—'}'),
                          _CompactValue('F', '${playback.f ?? '—'}'),
                        ],
                      ),
                ),
              ],
              if (canControlPlayback) ...<Widget>[
                BoxStyler().height($Spaces.xxs())(),
                PressableBox(
                  onPress: onTogglePause,
                  style: $Styles.button.color($Colors.input()),
                  child:
                      FlexBoxStyler()
                          .row()
                          .mainAxisAlignment(.center)
                          .spacing($Spaces.xs())(
                        children: <Widget>[
                          IconStyler().size(18).color($Colors.primary())(
                            icon: isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                          ),
                          TextStyler().style($TextStyles.counter())(
                            isPaused ? 'Resume playback' : 'Pause playback',
                          ),
                        ],
                      ),
                ),
              ],
              FlexBoxStyler().row().mainAxisAlignment(.spaceBetween)(
                children: <Widget>[
                  TextStyler().style($TextStyles.smallLabel())(
                    'Playback speed',
                  ),
                  for (final int milliseconds in <int>[1000, 500, 300, 0])
                    _SpeedChip(
                      milliseconds: milliseconds,
                      selected: speedMilliseconds == milliseconds,
                      onPressed: canControlPlayback
                          ? () => onChangeSpeed(milliseconds)
                          : null,
                    ),
                ],
              ),
            ],
          ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('speedMilliseconds', speedMilliseconds));
    properties.add(
      DiagnosticsProperty<bool>('canControlPlayback', canControlPlayback),
    );
    properties.add(DiagnosticsProperty<ProcessingState>('run', run));
    properties.add(DiagnosticsProperty<PlaybackState>('playback', playback));
    properties.add(
      ObjectFlagProperty<VoidCallback>.has('onTogglePause', onTogglePause),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<int>>.has(
        'onChangeSpeed',
        onChangeSpeed,
      ),
    );
  }
}

class _TraceGrid extends StatelessWidget {
  const new({required this.playback});

  final PlaybackState playback;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 310),
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _TraceGridPainter(
            playback: playback,
            emptyColor: $Colors.surface.resolve(context),
            backgroundColor: $Colors.gridBackground.resolve(context),
            blockedColor: $Colors.gridBlocked.resolve(context),
            startColor: $Colors.gridStart.resolve(context),
            endColor: $Colors.gridDestination.resolve(context),
            routeColor: $Colors.gridPath.resolve(context),
            currentColor: $Colors.primary.resolve(context),
            candidateColor: $Colors.gridPathLegend.resolve(context),
            textColor: $Colors.textPrimary.resolve(context),
          ),
        ),
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<PlaybackState>('playback', playback));
  }
}

/// Canvas-based grid: avoids building up to 9,801 widgets per A* step.
class _TraceGridPainter extends CustomPainter {
  const new({
    required this.playback,
    required this.emptyColor,
    required this.backgroundColor,
    required this.blockedColor,
    required this.startColor,
    required this.endColor,
    required this.routeColor,
    required this.currentColor,
    required this.candidateColor,
    required this.textColor,
  });

  final PlaybackState playback;
  final Color emptyColor;
  final Color backgroundColor;
  final Color blockedColor;
  final Color startColor;
  final Color endColor;
  final Color routeColor;
  final Color currentColor;
  final Color candidateColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final PathTask? task = playback.task;
    if (task == null) return;
    final int n = task.field.length;
    if (n == 0) return;

    final double dimension = math.min(size.width, size.height);
    final double cell = dimension / n;
    final double inset = n > 35 ? 0.1 : 1.0;
    final Paint paint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, paint);

    final Set<int> pathIndices = playback.path
        .map((GridPoint p) => p.y * n + p.x)
        .toSet();

    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        final int index = y * n + x;
        final bool blocked = task.field[y][x] == 'X';
        final bool start = task.start.x == x && task.start.y == y;
        final bool end = task.end.x == x && task.end.y == y;
        final bool current =
            playback.current?.x == x && playback.current?.y == y;
        final bool candidate =
            playback.candidate?.x == x && playback.candidate?.y == y;

        if (blocked) {
          paint.color = blockedColor;
        } else if (start) {
          paint.color = startColor;
        } else if (end) {
          paint.color = endColor;
        } else if (current) {
          paint.color = currentColor;
        } else if (candidate) {
          paint.color = candidateColor;
        } else if (pathIndices.contains(index)) {
          paint.color = routeColor;
        } else if (playback.expandedCells.contains(index)) {
          paint.color = currentColor.withValues(alpha: 0.23);
        } else {
          paint.color = emptyColor;
        }

        canvas.drawRect(
          Rect.fromLTWH(
            x * cell + inset / 2,
            y * cell + inset / 2,
            math.max(0, cell - inset),
            math.max(0, cell - inset),
          ),
          paint,
        );

        if (n <= 7 && cell >= 24) {
          final TextPainter text = TextPainter(
            text: TextSpan(
              text: '$x,$y',
              style: TextStyle(
                fontSize: math.min(11, cell / 4),
                color: blocked ? Colors.white : textColor,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(
            canvas,
            Offset(
              x * cell + (cell - text.width) / 2,
              y * cell + (cell - text.height) / 2,
            ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TraceGridPainter oldDelegate) =>
      oldDelegate.playback != playback ||
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.currentColor != currentColor;
}

class _CompactValue extends StatelessWidget {
  const new(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) =>
      FlexBoxStyler()
          .column()
          .crossAxisAlignment(.start)
          .spacing($Spaces.xxs())(
        children: <Widget>[
          TextStyler()
              .style($TextStyles.monoLabel())
              .fontSize(10)
              .color($Colors.textSecondary())(label),
          TextStyler().style($TextStyles.counter())(value),
        ],
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
    properties.add(StringProperty('value', value));
  }
}

class _SpeedChip extends StatelessWidget {
  const new({
    required this.milliseconds,
    required this.selected,
    required this.onPressed,
  });

  final int milliseconds;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => PressableBox(
    enabled: onPressed != null,
    onPress: onPressed,
    style: BoxStyler()
        .color(selected ? $Colors.gridBackground() : $Colors.input())
        .shapeStadium()
        .paddingX($Spaces.xs())
        .paddingY($Spaces.xxs()),
    child: TextStyler()
        .style($TextStyles.caption())
        .color(
          selected ? $Colors.primary() : $Colors.textSecondary(),
        )(milliseconds == 0 ? 'MAX' : '${milliseconds}ms'),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('milliseconds', milliseconds));
    properties.add(DiagnosticsProperty<bool>('selected', selected));
    properties.add(
      ObjectFlagProperty<VoidCallback?>.has('onPressed', onPressed),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const new({required this.status});

  final ProcessingStatus status;

  @override
  Widget build(BuildContext context) {
    final bool failed = status == ProcessingStatus.failure;
    return BoxStyler()
        .shapeStadium()
        .color(failed ? $Colors.input() : $Colors.gridBackground())
        .paddingX($Spaces.xs())
        .paddingY($Spaces.xxs())(
      child: TextStyler()
          .style($TextStyles.bodyMedium())
          .fontWeight(.w600)
          .color(
            failed ? $Colors.error() : $Colors.primary(),
          )(status.statusLabel),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<ProcessingStatus>('status', status));
  }
}

class _Statistic extends StatelessWidget {
  const new({required this.label, required this.value, this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) =>
      FlexBoxStyler()
          .column()
          .crossAxisAlignment(.start)
          .spacing($Spaces.xxs())(
        children: <Widget>[
          TextStyler().style($TextStyles.monoLabel())(label),
          TextStyler()
              .style($TextStyles.counter())
              .color(accent ? $Colors.primary() : $Colors.textPrimary())(
            value,
          ),
        ],
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
    properties.add(StringProperty('value', value));
    properties.add(DiagnosticsProperty<bool>('accent', accent));
  }
}

class _LinearProgress extends StatelessWidget {
  const new({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) =>
        StackBoxStyler().alignment(.centerLeft)(
          children: <Widget>[
            BoxStyler()
                .width(constraints.maxWidth)
                .height(6)
                .shapeStadium()
                .color($Colors.gridBackground())(),
            if (progress > 0)
              BoxStyler()
                  .width(constraints.maxWidth * progress)
                  .height(6)
                  .shapeStadium()
                  .color($Colors.primary())(),
          ],
        ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('progress', progress));
  }
}

class _ProcessingAction extends StatelessWidget {
  const new({
    required this.status,
    required this.retryingSubmission,
    required this.onPressed,
  });

  final ProcessingStatus status;
  final bool retryingSubmission;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled =
        status == ProcessingStatus.readyToSend ||
        status == ProcessingStatus.failure ||
        status == ProcessingStatus.success;
    final bool sending = status == ProcessingStatus.sending;
    final IconData icon = switch (status) {
      ProcessingStatus.readyToSend => Icons.cloud_upload_outlined,
      ProcessingStatus.failure => Icons.refresh_rounded,
      ProcessingStatus.success => Icons.check_circle_outline_rounded,
      _ => Icons.lock_outline_rounded,
    };

    return PressableBox(
      enabled: enabled,
      onPress: onPressed,
      style: $Styles.button.color(
        enabled ? $Colors.primary() : $Colors.input(),
      ),
      child:
          FlexBoxStyler()
              .row()
              .mainAxisAlignment(.center)
              .crossAxisAlignment(.center)
              .spacing($Spaces.xs())(
            children: <Widget>[
              if (sending)
                BoxStyler().size(17, 17)(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: $Colors.textSecondary.resolve(context),
                  ),
                )
              else
                IconStyler()
                    .size(18)
                    .color(
                      enabled ? $Colors.onPrimary() : $Colors.textSecondary(),
                    )(icon: icon),
              TextStyler()
                  .style($TextStyles.labelButton())
                  .color(
                    enabled ? $Colors.onPrimary() : $Colors.textSecondary(),
                  )(
                status.processingLabel(retryingSubmission: retryingSubmission),
              ),
            ],
          ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<ProcessingStatus>('status', status));
    properties.add(
      DiagnosticsProperty<bool>('retryingSubmission', retryingSubmission),
    );
    properties.add(
      ObjectFlagProperty<VoidCallback>.has('onPressed', onPressed),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const new({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) =>
      BoxStyler()
          .color($Colors.surface())
          .borderRadiusAll($Radius.compact())
          .paddingAll($Spaces.sm())(
        child: FlexBoxStyler().row().spacing($Spaces.xs())(
          children: <Widget>[
            IconStyler().size(18).color($Colors.error())(
              icon: Icons.error_outline_rounded,
            ),
            BoxStyler().wrap(.flexible(flex: 1))(
              child: TextStyler()
                  .style($TextStyles.smallLabel())
                  .color($Colors.error())(message),
            ),
          ],
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('message', message));
  }
}
