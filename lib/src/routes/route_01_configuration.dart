import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mix/mix.dart';

import '../providers.dart';
import '../routes.dart';
import '../styles.dart';
import '../utils/guard_hook.dart';
import '../widgets/route_header.dart';

part 'route_01_configuration.g.dart';

/// The route used to configure the pathfinding API endpoint.
@TypedGoRoute<ConfigurationRoute>(path: '/configure')
class ConfigurationRoute extends GoRouteData with $ConfigurationRoute {
  /// Creates the configuration route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      state.extra is ConfigurationScreen
      ? state.extra! as ConfigurationScreen
      : const ConfigurationScreen();

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

/// Configures and persists the URL used by the pathfinding workflow.
class ConfigurationScreen extends HookConsumerWidget {
  /// Creates the API configuration screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScrollController scrollController = PrimaryScrollController.of(
      context,
    );
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final GoRouter router = GoRouter.of(context);

    final GuardCallback guarded = useGuard();
    final ValueNotifier<bool> isStarting = useState(false);
    final ValueNotifier<bool> editedByUser = useState(false);
    final ValueNotifier<String> validationError = useState('');
    final GlobalKey<State<StatefulWidget>> urlKey = useMemoized(GlobalKey.new);
    final TextEditingController urlController = useTextEditingController();
    final FocusNode urlFocusNode = useFocusNode();

    Uri? getUri() => parseUrl(urlController.text.trim());

    useFuture(
      useMemoized(() async {
        urlFocusNode.addListener(() async {
          final Uri? uri = getUri();
          if (!urlFocusNode.hasFocus && uri != null) {
            await ref.read(endpointUrlProvider.notifier).set(uri);
          }

          Future<void>.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              scrollController.animateTo(
                mediaQuery.size.height,
                curve: Curves.easeOut,
                duration: const Duration(milliseconds: 300),
              );
            }
          });
        });

        final Uri? uri = await ref.read(endpointUrlProvider.future);
        if (uri != null) {
          urlController.text = uri.toString();
        }
      }),
    );

    Future<void> onUrlChanged() async {
      editedByUser.value = true;
      final Uri? uri = getUri();
      if (uri == null) {
        validationError.value = 'Please enter a valid HTTP or HTTPS URL.';
        return;
      }
      validationError.value = '';
    }

    Future<void> startCalculation() async {
      isStarting.value = true;
      validationError.value = '';

      try {
        final Uri? uri = getUri();
        if (uri == null) {
          validationError.value = 'Please enter API url in the input field.';
          return;
        }
        await ref.read(endpointUrlProvider.notifier).set(uri);
        if (!context.mounted) return;
        // Explicitly starting a new run clears stale results and A* playback.
        ref.read(processingProvider.notifier).reset();
        Routes.processing.go(router);
      } on Exception catch (_) {
        validationError.value = 'Unable to start. Please try again.';
      } finally {
        isStarting.value = false;
      }
    }

    Widget buildUrlInput() =>
        BoxStyler()
            .color($Colors.input())
            .borderRadiusAll($Radius.compact())
            .border(
              .color(
                validationError.value.isNotEmpty
                    ? $Colors.error()
                    : Colors.transparent,
              ).width(1),
            )
            .height(48)
            .paddingX($Spaces.sm())(
          child:
              FlexBoxStyler()
                  .row()
                  .crossAxisAlignment(.center)
                  .spacing($Spaces.xs())(
                key: urlKey,
                children: <Widget>[
                  IconStyler().size(18).color($Colors.textSecondary())(
                    icon: Icons.link_rounded,
                  ),
                  BoxStyler().wrap(.flexible(flex: 1))(
                    child: TextField(
                      controller: urlController,
                      focusNode: urlFocusNode,
                      enabled: !isStarting.value,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onChanged: (String value) => onUrlChanged(),
                      onEditingComplete: onUrlChanged,
                      onSubmitted: (_) => guarded(startCalculation),
                      cursorColor: $Colors.primary.resolve(context),
                      style: $TextStyles.labelButton.resolve(context),
                      decoration: InputDecoration.collapsed(
                        hintText: 'https://example.com/api?key=value',
                        hintStyle: $TextStyles.labelButton
                            .resolve(context)
                            .copyWith(
                              color: $Colors.textSecondary.resolve(context),
                            ),
                      ),
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                    ),
                  ),
                  if (urlController.text.isNotEmpty)
                    Pressable(
                      onPress: isStarting.value
                          ? null
                          : () async {
                              urlController.clear();
                              await onUrlChanged();
                            },
                      child: IconStyler()
                          .size(18)
                          .color(
                            $Colors.textSecondary(),
                          )(icon: Icons.cancel_outlined),
                    ),
                ],
              ),
        );

    Widget buildEndpointCard() =>
        $Styles.configurationCard.paddingAll($Spaces.md())(
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
                      TextStyler().style($TextStyles.h4())('API Endpoint'),
                      if (validationError.value.isEmpty &&
                              editedByUser.value ||
                          urlController.text.isNotEmpty)
                        BoxStyler()
                            .color($Colors.validation())
                            .shapeStadium()
                            .paddingX($Spaces.xs())
                            .paddingY($Spaces.xxs())(
                          child: FlexBoxStyler().row().spacing($Spaces.xxs())(
                            children: <Widget>[
                              IconStyler()
                                  .size(13)
                                  .color($Colors.accentText())(
                                icon: Icons.check_rounded,
                              ),
                              TextStyler()
                                  .style($TextStyles.bodyMedium())
                                  .color($Colors.accentText())('Validated'),
                            ],
                          ),
                        ),
                    ],
                  ),
                  buildUrlInput(),
                  TextStyler()
                      .style($TextStyles.smallLabel())
                      .height(1.45)
                      .color($Colors.error())(validationError.value),
                ],
              ),
        );

    Widget buildStartButton() => PressableBox(
      enabled: validationError.value.isEmpty && !isStarting.value,
      onPress: guarded(startCalculation),
      style: $Styles.primaryButton
          .color(
            validationError.value.isEmpty && !isStarting.value
                ? $Colors.primary()
                : $Colors.primaryDisabled(),
          )
          .shadow(
            .color(
              $Colors.primaryShadow.resolve(context),
            ).blurRadius(10).offset(x: 0, y: 5),
          ),
      child: isStarting.value
          ? BoxStyler().size(20, 20)(
              child: CircularProgressIndicator(
                color: $Colors.onPrimary.resolve(context),
                strokeWidth: 2,
              ),
            )
          : FlexBoxStyler()
                .row()
                .mainAxisAlignment(.center)
                .crossAxisAlignment(.center)
                .spacing($Spaces.sm())(
              children: <Widget>[
                TextStyler()
                    .style($TextStyles.strongLabel())
                    .color($Colors.onPrimary())('Start Calculation'),
                IconStyler().size(21).color($Colors.onPrimary())(
                  icon: Icons.arrow_forward_rounded,
                ),
              ],
            ),
    );

    return BoxStyler()
        .alignment(
          defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS
              ? .topCenter
              : .center,
        )
        .color($Colors.background())(
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails event) {
              final BuildContext? context = urlKey.currentContext;
              if (context == null) return;
              final RenderObject? renderObject = context.findRenderObject();
              if (renderObject is! RenderBox || !renderObject.hasSize) {
                return;
              }
              final Offset localPosition = renderObject.globalToLocal(
                event.globalPosition,
              );
              if (!(Offset.zero & renderObject.size).contains(localPosition)) {
                urlFocusNode.unfocus();
              }
            },
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child:
                  FlexBoxStyler()
                      .column()
                      .mainAxisAlignment(.center)
                      .crossAxisAlignment(.stretch)
                      .maxWidth(460)
                      .wrap(.box(BoxStyler().alignment(.center)))
                      .paddingX($Spaces.md())
                      .paddingTop($Spaces.sm())
                      .paddingBottom($Spaces.lg())(
                    children: <Widget>[
                      FlexBoxStyler()
                          .column()
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
                          ),
                          BoxStyler().height($Spaces.sm())(),
                          FlexBoxStyler()
                              .column()
                              .crossAxisAlignment(.start)
                              .spacing($Spaces.xs())(
                            children: <Widget>[
                              TextStyler().style($TextStyles.h3())(
                                'Configure your workspace',
                              ),
                              TextStyler().style($TextStyles.description())(
                                'Connect to your API endpoint to retrieve pathfinding '
                                'tasks and start calculating optimal routes.',
                              ),
                            ],
                          ),
                          const _TopologyCard(),
                          buildEndpointCard(),
                        ],
                      ),

                      BoxStyler()
                          .paddingTop($Spaces.md())
                          .paddingBottom($Spaces.xl())(
                        child: buildStartButton(),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An illustrative five-by-five topology; API tasks provide the real grids.
class _TopologyCard extends StatelessWidget {
  const new();

  // Cell values map the reference illustration to semantic grid colors.
  static const List<List<int>> _cells = <List<int>>[
    <int>[1, 3, 0, 2, 0],
    <int>[0, 3, 3, 0, 2],
    <int>[2, 0, 3, 2, 0],
    <int>[0, 0, 3, 3, 0],
    <int>[0, 2, 0, 3, 4],
  ];

  @override
  Widget build(
    BuildContext context,
  ) => $Styles.configurationCard.paddingAll($Spaces.md())(
    child:
        FlexBoxStyler()
            .column()
            .crossAxisAlignment(.stretch)
            .spacing($Spaces.sm())(
          children: <Widget>[
            _buildHeading(),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double size = math.min(280, constraints.maxWidth);
                return BoxStyler().alignment(.center)(child: _buildGrid(size));
              },
            ),
            FlexBoxStyler()
                .row()
                .mainAxisAlignment(.spaceBetween)
                .crossAxisAlignment(.center)(
              children: <Widget>[
                const _Legend(color: $Colors.gridStart, label: 'Start'),
                const _Legend(color: $Colors.gridBlocked, label: 'Blocked'),
                const _Legend(color: $Colors.gridPathLegend, label: 'Route'),
                const _Legend(color: $Colors.gridDestination, label: 'Target'),
              ],
            ),
          ],
        ),
  );

  Widget _buildHeading() =>
      FlexBoxStyler().row().crossAxisAlignment(.center).spacing($Spaces.xs())(
        children: <Widget>[
          IconStyler().size(17).color($Colors.primary())(
            icon: Icons.grid_on_rounded,
          ),
          BoxStyler().wrap(.flexible(flex: 1))(
            child: TextStyler().style($TextStyles.bodyLarge())(
              'Matrix Topology [5x5]',
            ),
          ),
          TextStyler()
              .style($TextStyles.bodyMedium())
              .color($Colors.textSecondary())('cost: 6 units'),
        ],
      );

  Widget _buildGrid(double size) =>
      BoxStyler()
          .size(size, size)
          .paddingAll($Spaces.xs())
          .color($Colors.gridBackground())
          .borderRadiusAll($Radius.compact())(
        child: FlexBoxStyler().column().spacing($Spaces.xxs())(
          children: <Widget>[
            for (int y = 0; y < _cells.length; y++)
              FlexBoxStyler()
                  .row()
                  .wrap(.flexible(flex: 1))
                  .spacing($Spaces.xxs())(
                children: <Widget>[
                  for (int x = 0; x < _cells[y].length; x++)
                    _buildCell(_cells[y][x]),
                ],
              ),
          ],
        ),
      );

  Widget _buildCell(int kind) {
    final $Colors color = switch (kind) {
      1 => $Colors.gridStart,
      2 => $Colors.gridBlocked,
      3 => $Colors.gridPath,
      4 => $Colors.gridDestination,
      _ => $Colors.surface,
    };

    final Widget content = switch (kind) {
      1 =>
        TextStyler()
            .style($TextStyles.bodyLarge())
            .fontWeight(.w800)
            .color($Colors.accentText())('S'),
      2 => IconStyler().size(17).color($Colors.onPrimary())(
        icon: Icons.close_rounded,
      ),
      3 => BoxStyler().size(8, 8).shapeCircle().color($Colors.accentText())(),
      4 =>
        TextStyler()
            .style($TextStyles.bodyLarge())
            .fontWeight(.w800)
            .color($Colors.onPrimary())('D'),
      _ => BoxStyler().size(0, 0)(),
    };

    return BoxStyler()
        .wrap(.flexible(flex: 1))
        .color(color())
        .borderRadiusAll($Radius.extraSmall())
        .alignment(.center)(child: content);
  }
}

class _Legend extends StatelessWidget {
  const new({required this.color, required this.label});

  final $Colors color;
  final String label;

  @override
  Widget build(BuildContext context) =>
      FlexBoxStyler().row().crossAxisAlignment(.center).spacing($Spaces.xxs())(
        children: <Widget>[
          BoxStyler().size(9, 9).shapeCircle().color(color())(),
          TextStyler()
              .style($TextStyles.bodyMedium())
              .color($Colors.textSecondary())(label),
        ],
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<$Colors>('color', color));
    properties.add(StringProperty('label', label));
  }
}
