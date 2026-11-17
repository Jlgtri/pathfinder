import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mix/mix.dart';

import '../api.dart';
import '../providers.dart';
import '../routes.dart';
import '../styles.dart';
import '../widgets/route_header.dart';

part 'route_04_details.g.dart';

/// Opens a calculated result by its zero-based index in pathResultsProvider.
///
/// The results list currently navigates with DetailsRoute(index). This keeps
/// that contract intact; the task itself is matched by its API identifier.
@TypedGoRoute<DetailsRoute>(path: '/details/:taskId')
class DetailsRoute extends GoRouteData with $DetailsRoute {
  /// Creates the details route.
  const new(this.taskId);

  /// Zero-based index of a result in pathResultsProvider.
  final int taskId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      state.extra is DetailsScreen
      ? state.extra! as DetailsScreen
      : DetailsScreen(taskId);

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

/// Read-only detailed view of a calculated shortest path.
class DetailsScreen extends HookConsumerWidget {
  /// Read-only detailed view of a calculated shortest path.
  const new(this.taskId, {super.key});

  /// The index passed by the results screen (not the API task ID).
  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PathResultRequest> results = ref.watch(pathResultsProvider);
    final AsyncValue<List<PathTask>> taskState = ref.watch(pathTasksProvider);
    final SubmissionState submission = ref.watch(resultsSubmissionProvider);

    if (taskId < 0 || taskId >= results.length) {
      return const _MissingDetails(
        message:
            'This result is no longer available. Return to the results list.',
      );
    }

    final PathResultRequest result = results[taskId];
    final List<PathTask> tasks = taskState.asData?.value ?? const <PathTask>[];

    PathTask? task;
    for (final PathTask item in tasks) {
      if (item.id == result.id) {
        task = item;
        break;
      }
    }

    if (task == null) {
      return const _MissingDetails(
        message:
            'The grid for this result is unavailable. '
            'The task must be loaded before it can be visualized.',
      );
    }

    final int rows = task.field.length;
    final int columns = rows == 0 ? 0 : task.field.first.length;
    if (rows == 0 ||
        columns == 0 ||
        task.field.any((String row) => row.length != columns)) {
      return const _MissingDetails(message: 'The received grid is invalid.');
    }

    bool? verified;
    for (final PathVerification verification in submission.verifications) {
      if (verification.id == result.id) {
        verified = verification.correct;
        break;
      }
    }

    final List<GridPoint> steps = result.result.steps;
    final int moves = steps.isEmpty ? 0 : steps.length - 1;
    final String coordinates = steps.isEmpty
        ? result.result.path.replaceAll('->', ' → ')
        : steps
              .map((GridPoint point) => '(${point.x},${point.y})')
              .join(' → ');

    final String statusLabel = switch (verified) {
      true => 'Verified',
      false => 'Invalid',
      null => 'Completed',
    };

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
                  .spacing($Spaces.md())
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
                    onBack: () {
                      final GoRouter router = GoRouter.of(context);
                      if (router.canPop()) {
                        router.pop();
                      } else {
                        Routes.results.go(router);
                      }
                    },
                  ),
                  BoxStyler().height($Spaces.sm())(),
                  FlexBoxStyler()
                      .column()
                      .crossAxisAlignment(.stretch)
                      .spacing($Spaces.xxs())(
                    children: <Widget>[
                      TextStyler().style($TextStyles.h3())('Shortest Path'),
                      TextStyler().style($TextStyles.description())(
                        'Visual representation of the calculated optimal '
                        'route across ${rows * columns} matrix nodes.',
                      ),
                    ],
                  ),
                  FlexBoxStyler().row().spacing($Spaces.xs())(
                    children: <Widget>[
                      BoxStyler().wrap(.flexible(flex: 1))(
                        child: _MetricCard(
                          label: 'MOVES',
                          value: '$moves',
                          suffix: moves == 1 ? 'hop' : 'hops',
                        ),
                      ),
                      BoxStyler().wrap(.flexible(flex: 1))(
                        child: _MetricCard(
                          label: 'GRID SIZE',
                          value: '$columns × $rows',
                          suffix: 'nodes',
                        ),
                      ),
                      BoxStyler().wrap(.flexible(flex: 1))(
                        child: _MetricCard(
                          label: 'STATUS',
                          value: statusLabel,
                          status: true,
                          error: verified == false,
                        ),
                      ),
                    ],
                  ),
                  FlexBoxStyler().row().spacing($Spaces.xs())(
                    children: <Widget>[
                      IconStyler().size(16).color($Colors.primary())(
                        icon: Icons.place_outlined,
                      ),
                      TextStyler().style($TextStyles.eyebrow())(
                        'COORDINATE MATRIX [X, Y]',
                      ),
                    ],
                  ),
                  BoxStyler()
                      .color($Colors.surface())
                      .borderRadiusAll($Radius.small())
                      .paddingAll($Spaces.xs())(
                    child: _MatrixGrid(task: task, steps: steps),
                  ),
                  const _GridLegend(),
                  _RouteCoordinatesCard(
                    coordinates: coordinates,
                    nodeCount: steps.length,
                  ),
                ],
              ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) => super
      .debugFillProperties(properties..add(IntProperty('taskId', taskId)));
}

class _MetricCard extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    this.suffix,
    this.status = false,
    this.error = false,
  });

  final String label;
  final String value;
  final String? suffix;
  final bool status;
  final bool error;

  @override
  Widget build(BuildContext context) => $Styles.metric(
    child:
        FlexBoxStyler()
            .column()
            .crossAxisAlignment(.stretch)
            .spacing($Spaces.xxs())(
          children: <Widget>[
            TextStyler()
                .style($TextStyles.eyebrow())
                .maxLines(1)
                .overflow(.ellipsis)(label),
            FlexBoxStyler().row().crossAxisAlignment(.center).spacing(4)(
              children: <Widget>[
                if (status)
                  IconStyler()
                      .size(12)
                      .color(
                        error ? $Colors.error() : $Colors.gridDestination(),
                      )(icon: Icons.circle),
                BoxStyler().wrap(.flexible(flex: 1))(
                  child: TextStyler()
                      .style($TextStyles.metricValue())
                      .color(
                        status
                            ? error
                                  ? $Colors.error()
                                  : $Colors.gridDestination()
                            : $Colors.textPrimary(),
                      )
                      .maxLines(1)
                      .overflow(.ellipsis)(value),
                ),
              ],
            ),
            if (suffix != null)
              TextStyler()
                  .maxLines(1)
                  .style($TextStyles.smallLabel())
                  .fontSize(11)(suffix!),
          ],
        ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) =>
      super.debugFillProperties(
        properties
          ..add(StringProperty('label', label))
          ..add(StringProperty('value', value))
          ..add(StringProperty('suffix', suffix))
          ..add(DiagnosticsProperty<bool>('status', status))
          ..add(DiagnosticsProperty<bool>('error', error)),
      );
}

/// The grid always uses the API's coordinate convention:
/// (0,0) is at the TOP LEFT, x increases to the right, y increases downward.
class _MatrixGrid extends StatelessWidget {
  const new({required this.task, required this.steps});

  final PathTask task;
  final List<GridPoint> steps;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final int columns = task.field.first.length;
      final int rows = task.field.length;
      final double viewportWidth = constraints.maxWidth;
      final double aspect = rows / columns;
      final double viewportHeight = viewportWidth * aspect;

      // Paint large grids at a readable intrinsic size, then fit them inside
      // the viewport. InteractiveViewer can scale the vector painting back up.
      final double cellSize = math.max(52, viewportWidth / columns);
      final double boardWidth = columns * cellSize;
      final double boardHeight = rows * cellSize;

      final _PathMatrixPainter painter = _PathMatrixPainter(
        task: task,
        steps: steps,
        startColor: const Color(0xFF64FFDA),
        endColor: const Color(0xFF009688),
        blockedColor: const Color(0xFF000000),
        pathColor: const Color(0xFF4CAF50),
        emptyColor: const Color(0xFFFFFFFF),
      );

      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: viewportWidth,
          height: viewportHeight,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 18,
            child: SizedBox(
              width: viewportWidth,
              height: viewportHeight,
              child: FittedBox(
                child: SizedBox(
                  width: boardWidth,
                  height: boardHeight,
                  child: CustomPaint(painter: painter),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<PathTask>('task', task));
    properties.add(IterableProperty<GridPoint>('steps', steps));
  }
}

class _PathMatrixPainter extends CustomPainter {
  new({
    required this.task,
    required this.steps,
    required this.startColor,
    required this.endColor,
    required this.blockedColor,
    required this.pathColor,
    required this.emptyColor,
  });

  final PathTask task;
  final List<GridPoint> steps;
  final Color startColor;
  final Color endColor;
  final Color blockedColor;
  final Color pathColor;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final int rows = task.field.length;
    final int columns = task.field.first.length;
    final double cellWidth = size.width / columns;
    final double cellHeight = size.height / rows;
    final double unit = math.min(cellWidth, cellHeight);

    final Map<int, int> routeOrder = <int, int>{};
    for (int i = 0; i < steps.length; i++) {
      final GridPoint point = steps[i];
      if (point.x >= 0 &&
          point.x < columns &&
          point.y >= 0 &&
          point.y < rows) {
        routeOrder[point.y * columns + point.x] = i;
      }
    }

    final Paint cellPaint = Paint()..style = PaintingStyle.fill;
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFDDE1EA);

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < columns; x++) {
        final int key = y * columns + x;
        final bool start = x == task.start.x && y == task.start.y;
        final bool end = x == task.end.x && y == task.end.y;
        final bool blocked = task.field[y][x] == 'X';
        final int? step = routeOrder[key];

        cellPaint.color = start
            ? startColor
            : end
            ? endColor
            : blocked
            ? blockedColor
            : step != null
            ? pathColor
            : emptyColor;

        final Rect cell = Rect.fromLTWH(
          x * cellWidth,
          y * cellHeight,
          cellWidth,
          cellHeight,
        );
        canvas.drawRect(cell, cellPaint);
        canvas.drawRect(cell, borderPaint);

        final Color textColor = blocked || end || (step != null && !start)
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF1F2937);

        final String coordinates = '($x,$y)';
        final bool marked = start || end || blocked || step != null;
        final double font = math.min(12, math.max(9, unit * 0.16));
        final String? sublabel = start
            ? 'START'
            : end
            ? 'GOAL'
            : step != null
            ? 'STEP $step'
            : null;

        if (marked && unit >= 50) {
          if (blocked) {
            _paintText(
              canvas,
              '⊘',
              Offset(cell.center.dx, cell.center.dy - font * 0.8),
              color: textColor,
              fontSize: font * 1.35,
              bold: true,
            );
          }
          _paintText(
            canvas,
            coordinates,
            Offset(
              cell.center.dx,
              cell.center.dy + (blocked ? font * 0.65 : -font * 0.35),
            ),
            color: textColor,
            fontSize: font,
            bold: true,
          );
          if (sublabel != null) {
            _paintText(
              canvas,
              sublabel,
              Offset(cell.center.dx, cell.center.dy + font * 0.9),
              color: textColor,
              fontSize: math.max(7, font * 0.75),
              bold: true,
            );
          }
        } else if (unit >= 24) {
          _paintText(
            canvas,
            coordinates,
            cell.center,
            color: textColor,
            fontSize: font,
            bold: marked,
          );
        }
      }
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset center, {
    required Color color,
    required double fontSize,
    bool bold = false,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PathMatrixPainter old) =>
      old.task != task ||
      old.steps != steps ||
      old.startColor != startColor ||
      old.endColor != endColor ||
      old.blockedColor != blockedColor ||
      old.pathColor != pathColor ||
      old.emptyColor != emptyColor;
}

class _GridLegend extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) =>
      BoxStyler()
          .color($Colors.surface())
          .borderRadiusAll($Radius.compact())
          .paddingAll($Spaces.xs())(
        child: const Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _LegendItem('Start', Color(0xFF64FFDA)),
            _LegendItem('End', Color(0xFF009688)),
            _LegendItem('Path', Color(0xFF4CAF50)),
            _LegendItem('Blocked', Color(0xFF000000)),
            _LegendItem('Empty', Color(0xFFFFFFFF), outline: true),
          ],
        ),
      );
}

class _LegendItem extends StatelessWidget {
  const new(this.label, this.color, {this.outline = false});

  final String label;
  final Color color;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final BoxStyler swatch = BoxStyler()
        .size(13, 13)
        .color(color)
        .borderRounded(2);

    return FlexBoxStyler().row().mainAxisSize(.min).spacing(5)(
      children: <Widget>[
        if (outline)
          swatch.borderAll(color: const Color(0xFFDDE1EA), width: 1)()
        else
          swatch(),
        TextStyler()
            .style($TextStyles.labelButton())
            .color($Colors.textSecondary())(label),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
    properties.add(ColorProperty('color', color));
    properties.add(DiagnosticsProperty<bool>('outline', outline));
  }
}

class _RouteCoordinatesCard extends StatelessWidget {
  const new({required this.coordinates, required this.nodeCount});

  final String coordinates;
  final int nodeCount;

  @override
  Widget build(BuildContext context) => $Styles.card(
    child:
        FlexBoxStyler()
            .column()
            .crossAxisAlignment(.stretch)
            .spacing($Spaces.sm())(
          children: <Widget>[
            FlexBoxStyler().row().mainAxisAlignment(.spaceBetween)(
              children: <Widget>[
                FlexBoxStyler().row().spacing($Spaces.xs())(
                  children: <Widget>[
                    IconStyler().size(18).color($Colors.primary())(
                      icon: Icons.alt_route_rounded,
                    ),
                    TextStyler().style($TextStyles.cardTitle())(
                      'Route Coordinates',
                    ),
                  ],
                ),
                BoxStyler()
                    .shapeStadium()
                    .color($Colors.gridBackground())
                    .paddingX($Spaces.xs())
                    .paddingY($Spaces.xxs())(
                  child: TextStyler()
                      .style($TextStyles.strongLabel())
                      .color($Colors.primary())('$nodeCount NODES'),
                ),
              ],
            ),
            BoxStyler()
                .color($Colors.input())
                .borderRadiusAll($Radius.compact())
                .paddingAll($Spaces.xs())(
              child:
                  FlexBoxStyler()
                      .row()
                      .padding(.horizontal($Spaces.sm()))
                      .crossAxisAlignment(.center)
                      .spacing($Spaces.md())(
                    children: <Widget>[
                      BoxStyler().wrap(.flexible(flex: 1))(
                        child: TextStyler().style($TextStyles.coordinates())(
                          coordinates.isEmpty
                              ? 'No available route'
                              : coordinates,
                        ),
                      ),
                      PressableBox(
                        onPress: () async {
                          await Clipboard.setData(
                            ClipboardData(text: coordinates),
                          );
                        },
                        style: BoxStyler()
                            .size(38, 38)
                            .color($Colors.surface())
                            .borderRadiusAll($Radius.extraSmall())
                            .alignment(.center)
                            .onPressed(.scale(0.97)),
                        child: IconStyler()
                            .size(18)
                            .color(
                              $Colors.textPrimary(),
                            )(icon: Icons.copy_rounded),
                      ),
                    ],
                  ),
            ),
            FlexBoxStyler()
                .row()
                .crossAxisAlignment(.start)
                .spacing($Spaces.xs())(
              children: <Widget>[
                IconStyler().size(17).color($Colors.primary())(
                  icon: Icons.info_outline_rounded,
                ),
                BoxStyler().wrap(.flexible(flex: 1))(
                  child:
                      TextStyler().style($TextStyles.smallLabel()).height(1.4)(
                        'This route represents the shortest calculated path '
                        'from the starting position to the destination.',
                      ),
                ),
              ],
            ),
          ],
        ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('coordinates', coordinates));
    properties.add(IntProperty('nodeCount', nodeCount));
  }
}

class _MissingDetails extends ConsumerWidget {
  const new({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      BoxStyler().color($Colors.background()).alignment(.center)(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: BoxStyler().paddingX($Spaces.md())(
                child:
                    FlexBoxStyler()
                        .column()
                        .mainAxisSize(.min)
                        .crossAxisAlignment(.stretch)
                        .spacing($Spaces.md())(
                      children: <Widget>[
                        RouteHeader(
                          isDark:
                              ref.watch(themeProvider).asData?.value ==
                              Themes.dark,
                          onToggleTheme: () {
                            ref.read(themeProvider.notifier).toggle();
                          },
                          onBack: () =>
                              Routes.results.go(GoRouter.of(context)),
                        ),
                        $Styles.card(
                          child:
                              FlexBoxStyler()
                                  .column()
                                  .crossAxisAlignment(.stretch)
                                  .spacing($Spaces.md())(
                                children: <Widget>[
                                  TextStyler().style($TextStyles.h3())(
                                    'Result unavailable',
                                  ),
                                  TextStyler().style(
                                    $TextStyles.description(),
                                  )(message),
                                  PressableBox(
                                    onPress: () => Routes.results.go(
                                      GoRouter.of(context),
                                    ),
                                    style: $Styles.button
                                        .color($Colors.primary())
                                        .height(44),
                                    child: TextStyler()
                                        .style($TextStyles.labelButton())
                                        .color(
                                          $Colors.onPrimary(),
                                        )('Back to results'),
                                  ),
                                ],
                              ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('message', message));
  }
}
