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
import 'route_04_details.dart';

part 'route_03_results.g.dart';

/// Shows the paths computed by A* and the server's verification summary.
@TypedGoRoute<ResultsRoute>(path: '/results')
class ResultsRoute extends GoRouteData with $ResultsRoute {
  /// Creates the results route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      state.extra is ResultsScreen
      ? state.extra! as ResultsScreen
      : const ResultsScreen();

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

/// Displays results from the dedicated Riverpod providers, without refetching.
class ResultsScreen extends HookConsumerWidget {
  /// Creates the results list screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PathResultRequest> results = ref.watch(pathResultsProvider);
    final ProcessingState processing = ref.watch(processingProvider);
    final SubmissionState submission = ref.watch(resultsSubmissionProvider);
    final AsyncValue<List<PathTask>> tasks = ref.watch(pathTasksProvider);

    // Verification responses can arrive unordered. Match them by task ID,
    // not by their position in the response.
    final Map<String, bool> verificationById = <String, bool>{
      for (final PathVerification item in submission.verifications)
        item.id: item.correct,
    };
    final int validPaths = results
        .where((PathResultRequest item) => verificationById[item.id] == true)
        .length;
    final int verifiedPaths = results
        .where(
          (PathResultRequest item) => verificationById.containsKey(item.id),
        )
        .length;
    final bool hasVerification = verifiedPaths > 0;

    final int totalTasks =
        tasks.asData?.value.length ??
        (processing.total > 0 ? processing.total : results.length);

    final int validationPercent = results.isEmpty
        ? 0
        : (validPaths * 100 / results.length).round();

    final ValueNotifier<int> visibleCount = useState<int>(4);
    final int showing = math.min(visibleCount.value, results.length);

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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child:
              FlexBoxStyler()
                  .column()
                  .crossAxisAlignment(.stretch)
                  .spacing($Spaces.md())
                  .maxWidth(460)
                  .wrap(.box(.alignment(.center)))
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
                      Routes.processing.go(GoRouter.of(context));
                    },
                  ),
                  BoxStyler().height($Spaces.sm())(),
                  FlexBoxStyler()
                      .column()
                      .crossAxisAlignment(.stretch)
                      .spacing($Spaces.xxs())(
                    children: <Widget>[
                      TextStyler().style($TextStyles.h3())(
                        'Your calculated paths',
                      ),
                      TextStyler().style($TextStyles.description())(
                        'Explore the shortest routes calculated for each grid task.',
                      ),
                    ],
                  ),
                  _TelemetryCard(
                    totalTasks: totalTasks,
                    validPaths: validPaths,
                    hasVerification: hasVerification,
                    validationPercent: validationPercent,
                    submissionStatus: submission.status,
                  ),
                  if (results.isEmpty)
                    _EmptyResults(
                      error:
                          processing.errorMessage ??
                          submission.errorMessage ??
                          (tasks.hasError ? tasks.error.toString() : null),
                      onBack: () => Routes.processing.go(GoRouter.of(context)),
                    )
                  else ...<Widget>[
                    for (int index = 0; index < showing; index++)
                      _ResultTile(
                        index: index,
                        result: results[index],
                        verification: verificationById[results[index].id],
                        onTap: () => DetailsRoute(index).push<void>(context),
                      ),
                    _ResultListFooter(
                      visible: showing,
                      total: results.length,
                      onShowMore: showing < results.length
                          ? () => visibleCount.value = math.min(
                              visibleCount.value + 8,
                              results.length,
                            )
                          : null,
                    ),
                  ],
                ],
              ),
        ),
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const new({
    required this.totalTasks,
    required this.validPaths,
    required this.hasVerification,
    required this.validationPercent,
    required this.submissionStatus,
  });

  final int totalTasks;
  final int validPaths;
  final bool hasVerification;
  final int validationPercent;
  final SubmissionStatus submissionStatus;

  @override
  Widget build(BuildContext context) {
    final bool sent = submissionStatus == SubmissionStatus.success;
    final bool failed = submissionStatus == SubmissionStatus.failure;

    final String badge = switch (submissionStatus) {
      SubmissionStatus.success => '● Sent successfully',
      SubmissionStatus.sending => '● Sending...',
      SubmissionStatus.failure => '● Send failed',
      SubmissionStatus.idle => '● Not submitted',
    };
    final String statusValue = hasVerification
        ? '$validationPercent%'
        : sent
        ? 'Sent'
        : failed
        ? 'Error'
        : 'Pending';

    return $Styles.card(
      child:
          FlexBoxStyler()
              .column()
              .crossAxisAlignment(.stretch)
              .spacing($Spaces.sm())(
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  TextStyler().style($TextStyles.telemetry())(
                    'TELEMETRY SUMMARY',
                  ),
                  BoxStyler()
                      .shapeStadium()
                      .color($Colors.gridBackground())
                      .paddingX($Spaces.xs())
                      .paddingY($Spaces.xxs())(
                    child: TextStyler()
                        .style($TextStyles.labelButton())
                        .color(
                          failed
                              ? $Colors.error()
                              : sent
                              ? $Colors.gridDestination()
                              : $Colors.textSecondary(),
                        )(badge),
                  ),
                ],
              ),
              FlexBoxStyler()
                  .row()
                  .spacing($Spaces.xs())
                  .crossAxisAlignment(.start)(
                children: <Widget>[
                  BoxStyler().wrap(.flexible(flex: 1))(
                    child: _SummaryMetric(
                      label: 'Total Tasks',
                      value: '$totalTasks',
                    ),
                  ),
                  BoxStyler().wrap(.flexible(flex: 1))(
                    child: _SummaryMetric(
                      label: 'Valid Paths',
                      value: hasVerification ? '$validPaths' : '—',
                      accent: true,
                    ),
                  ),
                  BoxStyler().wrap(.flexible(flex: 1))(
                    child: _SummaryMetric(
                      label: 'Status',
                      value: statusValue,
                      verified:
                          sent && hasVerification && validationPercent == 100,
                    ),
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
    properties.add(IntProperty('totalTasks', totalTasks));
    properties.add(IntProperty('validPaths', validPaths));
    properties.add(
      DiagnosticsProperty<bool>('hasVerification', hasVerification),
    );
    properties.add(IntProperty('validationPercent', validationPercent));
    properties.add(
      EnumProperty<SubmissionStatus>('submissionStatus', submissionStatus),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    this.accent = false,
    this.verified = false,
  });

  final String label;
  final String value;
  final bool accent;
  final bool verified;

  @override
  Widget build(BuildContext context) => $Styles.telemetryMetric(
    child:
        FlexBoxStyler()
            .column()
            .crossAxisAlignment(.start)
            .spacing($Spaces.xxs())(
          children: <Widget>[
            TextStyler()
                .style($TextStyles.smallLabel())
                .maxLines(1)
                .overflow(.ellipsis)(label),
            FlexBoxStyler().row().crossAxisAlignment(.center).spacing(4)(
              children: <Widget>[
                if (verified)
                  IconStyler().size(15).color($Colors.gridDestination())(
                    icon: Icons.check_circle_rounded,
                  ),
                BoxStyler().wrap(.flexible(flex: 1))(
                  child: TextStyler()
                      .style($TextStyles.metricValue())
                      .color(
                        accent
                            ? $Colors.primary()
                            : verified
                            ? $Colors.gridDestination()
                            : $Colors.textPrimary(),
                      )
                      .maxLines(1)
                      .overflow(.ellipsis)(value),
                ),
              ],
            ),
          ],
        ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
    properties.add(StringProperty('value', value));
    properties.add(DiagnosticsProperty<bool>('accent', accent));
    properties.add(DiagnosticsProperty<bool>('verified', verified));
  }
}

class _ResultTile extends StatelessWidget {
  const new({
    required this.index,
    required this.result,
    required this.verification,
    required this.onTap,
  });

  final int index;
  final PathResultRequest result;
  final bool? verification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String number = '${index + 1}'.padLeft(2, '0');
    final List<GridPoint> points = result.result.steps;
    final int moves = points.isEmpty ? 0 : points.length - 1;
    final String path = points.isEmpty
        ? result.result.path.replaceAll('->', ' → ')
        : points
              .map((GridPoint point) => '(${point.x},${point.y})')
              .join(' → ');

    return PressableBox(
      onPress: onTap,
      style: $Styles.resultCard,
      child:
          FlexBoxStyler()
              .row()
              .crossAxisAlignment(.center)
              .spacing($Spaces.sm())(
            children: <Widget>[
              $Styles.numberBadge(
                child: TextStyler()
                    .style($TextStyles.strongLabel())
                    .fontSize(11)('#$number'),
              ),
              BoxStyler().wrap(.flexible(flex: 1))(
                child:
                    FlexBoxStyler()
                        .column()
                        .crossAxisAlignment(.stretch)
                        .spacing($Spaces.xxs())(
                      children: <Widget>[
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            TextStyler().style($TextStyles.cardTitle())(
                              'Path Result $number',
                            ),
                            TextStyler().style($TextStyles.smallLabel())(
                              '· $moves moves',
                            ),
                            if (verification == false)
                              IconStyler().size(14).color($Colors.error())(
                                icon: Icons.error_outline_rounded,
                              ),
                          ],
                        ),
                        TextStyler()
                            .style($TextStyles.coordinates())
                            .maxLines(1)
                            .overflow(.ellipsis)(path),
                      ],
                    ),
              ),
              BoxStyler()
                  .size(32, 32)
                  .shapeCircle()
                  .color($Colors.input())
                  .alignment(.center)(
                child: IconStyler().size(18).color($Colors.textSecondary())(
                  icon: Icons.chevron_right_rounded,
                ),
              ),
            ],
          ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('index', index));
    properties.add(DiagnosticsProperty<bool?>('verification', verification));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
    properties.add(DiagnosticsProperty<PathResultRequest>('result', result));
  }
}

class _ResultListFooter extends StatelessWidget {
  const new({
    required this.visible,
    required this.total,
    required this.onShowMore,
  });

  final int visible;
  final int total;
  final VoidCallback? onShowMore;

  @override
  Widget build(BuildContext context) =>
      FlexBoxStyler()
          .column()
          .crossAxisAlignment(.center)
          .spacing($Spaces.sm())(
        children: <Widget>[
          FlexBoxStyler().row().mainAxisAlignment(.center).spacing(5)(
            children: <Widget>[
              IconStyler().size(7).color($Colors.textSecondary())(
                icon: Icons.circle,
              ),
              TextStyler()
                  .style($TextStyles.labelButton())
                  .color($Colors.textSecondary())(
                'Showing $visible of $total calculated vectors',
              ),
            ],
          ),
          if (onShowMore != null)
            PressableBox(
              onPress: onShowMore,
              style: BoxStyler()
                  .color($Colors.input())
                  .borderRadiusAll($Radius.compact())
                  .paddingX($Spaces.lg())
                  .paddingY($Spaces.sm())
                  .onPressed(.scale(0.98)),
              child: TextStyler()
                  .style($TextStyles.labelButton())
                  .fontSize(13)
                  .color($Colors.primary())('Show more results'),
            ),
        ],
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('visible', visible));
    properties.add(IntProperty('total', total));
    properties.add(
      ObjectFlagProperty<VoidCallback>.has('onShowMore', onShowMore),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const new({required this.error, required this.onBack});

  final String? error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => $Styles.card(
    child:
        FlexBoxStyler()
            .column()
            .crossAxisAlignment(.center)
            .spacing($Spaces.sm())(
          children: <Widget>[
            IconStyler().size(34).color($Colors.textSecondary())(
              icon: Icons.route_outlined,
            ),
            TextStyler().style($TextStyles.cardTitle())(
              'No calculated paths yet',
            ),
            TextStyler().style($TextStyles.description()).textAlign(.center)(
              error ?? 'Run a calculation to see its results here.',
            ),
            PressableBox(
              onPress: onBack,
              style: BoxStyler()
                  .color($Colors.primary())
                  .borderRadiusAll($Radius.compact())
                  .paddingX($Spaces.lg())
                  .paddingY($Spaces.sm())
                  .onPressed(.scale(0.98)),
              child: TextStyler()
                  .style($TextStyles.labelButton())
                  .color($Colors.onPrimary())('Back to processing'),
            ),
          ],
        ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('error', error));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onBack', onBack));
  }
}
