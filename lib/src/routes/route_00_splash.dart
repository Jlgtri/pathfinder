import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mix/mix.dart';

import '../generated/assets.gen.dart';
import '../providers.dart';
import '../styles.dart';

part 'route_00_splash.g.dart';

/// The welcome screen of the onboarding flow.
@TypedGoRoute<SplashRoute>(path: '/')
class SplashRoute extends GoRouteData with $SplashRoute {
  /// The welcome screen of the onboarding flow.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      state.extra is SplashScreen
      ? state.extra! as SplashScreen
      : const SplashScreen();

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

/// The welcome screen of the onboarding flow.
class SplashScreen extends HookConsumerWidget {
  /// The welcome screen of the onboarding flow.
  const new({
    this.showFirst = const Duration(seconds: 2),
    this.curve = Curves.easeInOut,
    this.transitionDuration = const Duration(seconds: 1),
    this.showSecond = const Duration(seconds: 1),
    super.key,
  });

  /// How much to show the first part.
  final Duration showFirst;

  /// How much time to animate the transition.
  final Curve curve;

  /// How much time to animate the transition.
  final Duration transitionDuration;

  /// How much to show the second part.
  final Duration showSecond;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = GoRouter.of(context);
    final $SourceAssets00SplashGen assets = Assets.source.assets.a00Splash;

    useFuture(
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (context.mounted) {
          ref.read(currentRouteProvider.notifier).seenSplash();
          ref.read(currentRouteProvider).go(router);
        }
      }),
    );

    return $Styles
        .futuristicBackground(context)
        .alignment(.center)
        .padding(.horizontal(20).vertical(64))(
      child: StackBoxStyler().keyframeAnimation(
        timeline: <KeyframeTrack<double>>[
          KeyframeTrack<double>('opacity', <Keyframe<double>>[
            .easeIn(1, 500.ms),
            .linear(1, 2000.ms),
            .easeOut(0, 500.ms),
            // extra waiting time for route navigation
            .linear(0, 1000.ms),
          ], initial: 0),
        ],
        styleBuilder: (KeyframeAnimationResult values, StackBoxStyler style) =>
            style.wrap(.opacity(values.get('opacity') as double)),
      )(children: <Widget>[assets.loader.lottie(animate: true, repeat: true)]),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) =>
      super.debugFillProperties(
        properties
          ..add(DiagnosticsProperty<Duration>('showFirst', showFirst))
          ..add(DiagnosticsProperty<Curve>('curve', curve))
          ..add(
            DiagnosticsProperty<Duration>(
              'transitionDuration',
              transitionDuration,
            ),
          )
          ..add(DiagnosticsProperty<Duration>('showSecond', showSecond)),
      );
}
