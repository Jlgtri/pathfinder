part of '../styles.dart';

/// Shared non-typography Mix stylers for the PathFinder workflow routes.
///
/// Typography lives in the $TextStyles tokens in styles.dart.
/// Keep reusable surfaces, buttons and badges here; colors and radii
/// resolve from the existing MixScope.
base mixin $Styles on BaseTheme {
  /// A slowly shifting multi-stop linear gradient background best used for
  /// app-level canvases.
  ///
  /// Animates between the background and surface colors on a 1-second ease curve.
  ///
  /// Example:
  /// ```dart
  /// Box(style: futuristicBackground(context))
  /// ```
  static BoxStyler futuristicBackground(BuildContext context) => BoxStyler()
      .gradient(
        .linear(
          .begin(.topLeft).end(.bottomRight).colors(<Color>[
            $Colors.background.resolve(context),
            $Colors.surface.resolve(context),
            $Colors.background.resolve(context),
          ]),
        ),
      )
      .animate(.ease(const Duration(seconds: 1)));

  static final BoxStyler configurationCard = BoxStyler()
      .color($Colors.surface())
      .borderRadiusAll($Radius.small())
      .border(.all(.color($Colors.border()).width(1)));

  static final BoxStyler card = BoxStyler()
      .color($Colors.surface())
      .borderRadiusAll($Radius.small())
      .paddingAll($Spaces.md());

  static final BoxStyler stats = BoxStyler()
      .color($Colors.input())
      .borderRadiusAll($Radius.extraSmall())
      .paddingX($Spaces.xs())
      .paddingY($Spaces.xxs());

  /// Detail metrics expand with their content to avoid vertical overflow.
  static final BoxStyler metric = BoxStyler()
      .minHeight(92)
      .color($Colors.surface())
      .borderRadiusAll($Radius.compact())
      .paddingX($Spaces.xs())
      .paddingY($Spaces.sm());

  static final BoxStyler telemetryMetric = BoxStyler()
      .color($Colors.input())
      .borderRadiusAll($Radius.compact())
      .paddingX($Spaces.xs())
      .paddingY($Spaces.sm());

  static final BoxStyler resultCard = BoxStyler()
      .color($Colors.surface())
      .borderRadiusAll($Radius.small())
      .paddingAll($Spaces.sm())
      .onPressed(.scale(0.99));

  static final BoxStyler numberBadge = BoxStyler()
      .color($Colors.gridBackground())
      .borderRadiusAll($Radius.extraSmall())
      .paddingX($Spaces.xs())
      .paddingY($Spaces.xxs());

  static final BoxStyler button = BoxStyler()
      .height(48)
      .borderRadiusAll($Radius.compact())
      .alignment(.center)
      .onPressed(.scale(0.98));

  static final BoxStyler primaryButton = button
      .height(52)
      .color($Colors.primary());
}
