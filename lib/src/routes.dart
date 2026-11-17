import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mix/mix.dart';

import 'providers.dart';
import 'routes/route_00_splash.dart';
import 'routes/route_01_configuration.dart';
import 'routes/route_02_processing.dart';
import 'routes/route_03_results.dart';
import 'routes/route_04_details.dart';
import 'styles.dart';

/// The route in the app.
enum Routes<Extra extends Object?> {
  /// The splash screen.
  splash<SplashScreen?>(SplashRoute()),

  /// The welcome screen.
  configuration<ConfigurationScreen?>(ConfigurationRoute()),

  /// The information screen.
  processing<ProcessingScreen?>(ProcessingRoute()),

  /// The home screen.
  results<ResultsScreen?>(ResultsRoute()),

  /// The book screen.
  details<DetailsScreen?>(DetailsRoute(0));

  /// The route in the app.
  new(this._route, {this.key});

  /// The internal value of this route.
  GoRouteData get route => _route!;
  final GoRouteData? _route;

  /// The key for this route.
  final Key? key;

  /// The router to use in app.
  static final List<RouteBase> routes = <RouteBase>[
    $splashRoute,
    $configurationRoute,
    $processingRoute,
    $resultsRoute,
    $detailsRoute,
  ];

  /// The route location as specified in [route].
  String get location => route.location;

  /// The wrapper method on [GoRouter.go].
  void go(GoRouter router, {Extra? extra}) =>
      router.go(location, extra: extra);

  /// The wrapper method on [GoRouter.push].
  Future<T?> push<T extends Object?>(GoRouter router, {Extra? extra}) =>
      router.push<T>(location, extra: extra);

  /// The wrapper method on [GoRouter.pushReplacement].
  Future<T?> pushReplacement<T extends Object?>(
    GoRouter router, {
    Extra? extra,
  }) => router.pushReplacement<T>(location, extra: extra);

  /// The wrapper method on [GoRouter.replace].
  Future<T?> replace<T extends Object?>(GoRouter router, {Extra? extra}) =>
      router.replace<T>(location, extra: extra);
}

/// The wrapper around [MaterialApp] to support hot reload.
@immutable
class RoutesApp extends HookConsumerWidget {
  /// The wrapper around [MaterialApp] to support hot reload.
  const new(this.router, {super.key});

  /// The router to use in the app.
  final GoRouter router;

  /// Navigator key used for testing.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Themes appTheme = ref.watch(themeProvider).requireValue;
    return MixScope(
      colors: appTheme.instance.colors,
      spaces: appTheme.instance.spaces,
      radii: appTheme.instance.radii,
      textStyles: appTheme.instance.textStyles,
      doubles: appTheme.instance.blurRadii,
      child: MaterialApp.router(
        title: 'Path Finder',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          overscroll: false,
        ),
        builder: (BuildContext context, Widget? child) {
          final ThemeData theme = Theme.of(context);
          final MediaQueryData mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
            child: DefaultTextStyle(
              style: theme.textTheme.titleMedium ?? const TextStyle(),
              textAlign: TextAlign.center,
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: appTheme == Themes.dark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: appTheme == Themes.dark
                      ? Brightness.dark
                      : Brightness.light,
                  systemNavigationBarIconBrightness: appTheme == Themes.dark
                      ? Brightness.light
                      : Brightness.dark,
                  systemNavigationBarColor: Colors.transparent,
                ),
                child: Material(child: child),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) =>
      super.debugFillProperties(
        properties..add(DiagnosticsProperty<GoRouter>('router', router)),
      );
}
