// ignore_for_file: public_member_api_docs

import 'package:material_ui/material_ui.dart';
import 'package:mix/mix.dart';

part 'styles/misc.dart';

enum Themes {
  light(LightTheme()),
  dark(DarkTheme());

  new(this.instance);

  /// Concrete theme implementation.
  final AppTheme instance;
}

enum Fonts {
  gotham('Gotham Pro'),
  sf('.SF Pro Text');

  new(this.font);

  /// Registered font family name.
  final String font;
}

enum $Colors {
  primary(ColorToken('color.primary')),
  background(ColorToken('color.background')),
  surface(ColorToken('color.surface')),
  textPrimary(ColorToken('color.textPrimary')),
  textSecondary(ColorToken('color.textSecondary')),
  border(ColorToken('color.border')),
  error(ColorToken('color.error')),
  warning(ColorToken('color.warning')),
  input(ColorToken('color.input')),
  gridBackground(ColorToken('color.gridBackground')),
  primaryDisabled(ColorToken('color.primaryDisabled')),
  primaryShadow(ColorToken('color.primaryShadow')),
  gridStart(ColorToken('color.gridStart')),
  gridBlocked(ColorToken('color.gridBlocked')),
  gridPath(ColorToken('color.gridPath')),
  gridPathLegend(ColorToken('color.gridPathLegend')),
  gridDestination(ColorToken('color.gridDestination')),
  accentText(ColorToken('color.accentText')),
  validation(ColorToken('color.validation')),
  onPrimary(ColorToken('color.onPrimary'));

  new(this.token);

  /// Underlying [MixToken].
  final ColorToken token;

  /// Returns a [ColorRef] for Mix styles.
  ColorRef call() => token();

  /// Resolves the concrete [Color] from context.
  Color resolve(BuildContext context) => token.resolve(context);
}

enum $GlassColors {
  primary(ColorToken('glass.primary')),
  secondary(ColorToken('glass.secondary')),
  border(ColorToken('glass.border')),
  shadow(ColorToken('glass.shadow')),

  neonBlue(ColorToken('glass.neonBlue')),
  neonPurple(ColorToken('glass.neonPurple')),
  neonPink(ColorToken('glass.neonPink'));

  new(this.token);

  /// Underlying [MixToken].
  final ColorToken token;

  /// Returns a [ColorRef] for Mix styles.
  ColorRef call() => token();

  /// Resolves the concrete [Color] from context.
  Color resolve(BuildContext context) => token.resolve(context);
}

enum $ComponentColors {
  cardGlass(ColorToken('component.cardGlass')),
  buttonGlass(ColorToken('component.buttonGlass')),
  navBar(ColorToken('component.navBar'));

  new(this.token);

  /// Underlying [MixToken].
  final ColorToken token;

  /// Returns a [ColorRef] for Mix styles.
  ColorRef call() => token();

  /// Resolves the concrete [Color] from context.
  Color resolve(BuildContext context) => token.resolve(context);
}

enum $TextStyles {
  h1(TextStyleToken('text.h1')),
  h2(TextStyleToken('text.h2')),
  h3(TextStyleToken('text.h3')),
  h4(TextStyleToken('text.h4')),
  bodyLarge(TextStyleToken('text.bodyLarge')),
  bodyMedium(TextStyleToken('text.bodyMedium')),
  caption(TextStyleToken('text.caption')),
  labelButton(TextStyleToken('text.labelButton')),

  // Shared semantic typography used across the PathFinder routes.
  description(TextStyleToken('text.description')),
  smallLabel(TextStyleToken('text.smallLabel')),
  monoLabel(TextStyleToken('text.monoLabel')),
  counter(TextStyleToken('text.counter')),
  telemetry(TextStyleToken('text.telemetry')),
  eyebrow(TextStyleToken('text.eyebrow')),
  metricValue(TextStyleToken('text.metricValue')),
  cardTitle(TextStyleToken('text.cardTitle')),
  coordinates(TextStyleToken('text.coordinates')),
  strongLabel(TextStyleToken('text.strongLabel')),
  brand(TextStyleToken('text.brand'));

  new(this.token);

  /// Underlying [MixToken].
  final TextStyleToken token;

  /// Returns a [TextStyleMixRef] for Mix styles.
  TextStyleMixRef call() => token.mix();

  /// Resolves the concrete [TextStyle].
  TextStyle resolve(BuildContext context) => token.resolve(context);
}

enum $Radius {
  extraSmall(RadiusToken('radius.extraSmall')),
  compact(RadiusToken('radius.compact')),
  small(RadiusToken('radius.small')),
  medium(RadiusToken('radius.medium')),
  large(RadiusToken('radius.large')),
  xlarge(RadiusToken('radius.xlarge'));

  new(this.token);

  /// Underlying [MixToken].
  final RadiusToken token;

  /// Returns a [RadiusRef] for Mix styles.
  RadiusRef call() => token();

  /// Resolves the concrete [Radius].
  Radius resolve(BuildContext context) => token.resolve(context);
}

enum $BlurRadius {
  xxsmall(DoubleToken('blurRadius.xxsmall')),
  xsmall(DoubleToken('blurRadius.xsmall')),
  small(DoubleToken('blurRadius.small')),
  medium(DoubleToken('blurRadius.medium')),
  large(DoubleToken('blurRadius.large')),
  xlarge(DoubleToken('blurRadius.xlarge'));

  new(this.token);

  /// Underlying [MixToken].
  final DoubleToken token;

  /// Returns the token reference value.
  double call() => token();

  /// Resolves the concrete value.
  double resolve(BuildContext context) => token.resolve(context);
}

enum $Spaces {
  xxs(SpaceToken('space.xxs')),
  xs(SpaceToken('space.xs')),
  sm(SpaceToken('space.sm')),
  md(SpaceToken('space.md')),
  lg(SpaceToken('space.lg')),
  xl(SpaceToken('space.xl')),
  xxl(SpaceToken('space.xxl'));

  new(this.token);

  /// Underlying [MixToken].
  final SpaceToken token;

  /// Returns the token reference value.
  double call() => token();

  /// Resolves the concrete spacing value.
  double resolve(BuildContext context) => token.resolve(context);
}

mixin AppTheme {
  /// Spacing scale tokens.
  Map<SpaceToken, double> get spaces;

  /// Blur radius tokens.
  Map<DoubleToken, double> get blurRadii;

  /// Radius tokens.
  Map<RadiusToken, Radius> get radii;

  /// Color tokens.
  Map<ColorToken, Color> get colors;

  /// Typography tokens.
  Map<TextStyleToken, TextStyle> get textStyles;
}

abstract base class BaseTheme implements AppTheme {
  const new();

  @override
  Map<SpaceToken, double> get spaces => <SpaceToken, double>{
    for (final $Spaces space in $Spaces.values)
      space.token: switch (space) {
        .xxs => 4,
        .xs => 8,
        .sm => 12,
        .md => 16,
        .lg => 24,
        .xl => 32,
        .xxl => 48,
      },
  };

  @override
  Map<RadiusToken, Radius> get radii => <RadiusToken, Radius>{
    for (final $Radius radius in $Radius.values)
      radius.token: switch (radius) {
        .extraSmall => const Radius.circular(8),
        .compact => const Radius.circular(12),
        .small => const Radius.circular(16),
        .medium => const Radius.circular(22),
        .large => const Radius.circular(28),
        .xlarge => const Radius.circular(36),
      },
  };

  @override
  Map<DoubleToken, double> get blurRadii => <DoubleToken, double>{
    for (final $BlurRadius radius in $BlurRadius.values)
      radius.token: switch (radius) {
        .xxsmall => 10,
        .xsmall => 20,
        .small => 30,
        .medium => 40,
        .large => 60,
        .xlarge => 80,
      },
  };

  @override
  Map<TextStyleToken, TextStyle> get textStyles {
    // Base tokens are reused by the more specific route typography variants.
    // This keeps all font sizes, weights, line heights and semantic colors in
    // the Mix theme, instead of duplicating them in widget-level TextStylers.
    final TextStyle h1 = TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: colors[$Colors.textPrimary.token],
      letterSpacing: -1,
    );
    final TextStyle h2 = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: colors[$Colors.textPrimary.token],
      letterSpacing: -0.5,
    );
    final TextStyle h3 = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: colors[$Colors.textPrimary.token],
      letterSpacing: -0.5,
    );
    final TextStyle h4 = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: colors[$Colors.textPrimary.token],
      letterSpacing: -0.5,
    );
    final TextStyle bodyLarge = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: colors[$Colors.textPrimary.token],
    );
    final TextStyle bodyMedium = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: colors[$Colors.textSecondary.token],
    );
    final TextStyle caption = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: colors[$Colors.textSecondary.token],
    );
    final TextStyle labelButton = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: colors[$Colors.textPrimary.token],
      letterSpacing: -0.2,
    );

    return <TextStyleToken, TextStyle>{
      for (final $TextStyles style in $TextStyles.values)
        style.token: switch (style) {
          .h1 => h1,
          .h2 => h2,
          .h3 => h3,
          .h4 => h4,
          .bodyLarge => bodyLarge,
          .bodyMedium => bodyMedium,
          .caption => caption,
          .labelButton => labelButton,
          .description => bodyMedium.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          .smallLabel => caption.copyWith(fontWeight: FontWeight.w400),
          .monoLabel => bodyMedium.copyWith(letterSpacing: 0.5),
          .counter => bodyLarge.copyWith(fontSize: 14),
          .telemetry => labelButton.copyWith(
            letterSpacing: 1,
            color: colors[$Colors.textSecondary.token],
          ),
          .eyebrow => labelButton.copyWith(
            letterSpacing: 0.9,
            color: colors[$Colors.textSecondary.token],
          ),
          .metricValue => bodyLarge.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          .cardTitle => bodyLarge.copyWith(fontSize: 16),
          .coordinates => labelButton.copyWith(
            fontSize: 12,
            height: 1.6,
            color: colors[$Colors.primary.token],
          ),
          .strongLabel => labelButton.copyWith(fontWeight: FontWeight.w700),
          .brand => caption.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        },
    };
  }
}

final class LightTheme extends BaseTheme {
  const new();

  @override
  Map<ColorToken, Color> get colors => <ColorToken, Color>{
    for (final $Colors color in $Colors.values)
      color.token: switch (color) {
        .primary => const Color(0xFF2862E8),
        .background => const Color(0xFFE7E7EE),
        .surface => const Color(0xFFFFFFFF),
        .textPrimary => const Color(0xFF1D1D1F),
        .textSecondary => const Color(0xFF5C5C66),
        .border => const Color(0xFFE1E4EA),
        .error => const Color(0xFFFF3B30),
        .warning => const Color(0xFFFFC857),
        .input => const Color(0xFFF5F3FD),
        .gridBackground => const Color(0xFFF0EEFA),
        .primaryDisabled => const Color(0xFFA8B9E3),
        .primaryShadow => const Color(0x332862E8),
        .gridStart => const Color(0xFF80EEDF),
        .gridBlocked => const Color(0xFF182132),
        .gridPath => const Color(0xFFA3E5DC),
        .gridPathLegend => const Color(0xFF45D3C3),
        .gridDestination => const Color(0xFF048676),
        .accentText => const Color(0xFF07695D),
        .validation => const Color(0xFF68EDDA),
        .onPrimary => const Color(0xFFFFFFFF),
      },

    for (final $GlassColors color in $GlassColors.values)
      color.token: switch (color) {
        .primary => const Color(0xB3FFFFFF),
        .secondary => const Color(0x80FFFFFF),
        .border => const Color(0x1A000000),
        .shadow => const Color(0x14000000),
        .neonBlue => const Color(0xFF4A90E2),
        .neonPurple => const Color(0xFF8B5CF6),
        .neonPink => const Color(0xFFEC4899),
      },

    for (final $ComponentColors color in $ComponentColors.values)
      color.token: switch (color) {
        .cardGlass => const Color(0xE8FFFFFF),
        .buttonGlass => const Color(0xE6FFFFFF),
        .navBar => const Color(0x00f7f8fa),
      },
  };
}

final class DarkTheme extends BaseTheme {
  const new();

  @override
  Map<ColorToken, Color> get colors => <ColorToken, Color>{
    for (final $Colors color in $Colors.values)
      color.token: switch (color) {
        .primary => const Color(0xFF4F83F5),
        .background => const Color(0xFF0B1020),
        .surface => const Color(0xFF171E2D),
        .textPrimary => const Color(0xFFFFFFFF),
        .textSecondary => const Color(0xB3FFFFFF),
        .border => const Color(0x1AFFFFFF),
        .error => const Color(0xFFFF453A),
        .warning => const Color(0xFFFFD60A),
        .input => const Color(0xFF222C41),
        .gridBackground => const Color(0xFF252D44),
        .primaryDisabled => const Color(0xFF4A5E86),
        .primaryShadow => const Color(0x334F83F5),
        .gridStart => const Color(0xFF64FFDA),
        .gridBlocked => const Color(0xFF020617),
        .gridPath => const Color(0xFF327E74),
        .gridPathLegend => const Color(0xFF48D1C0),
        .gridDestination => const Color(0xFF0C9F8A),
        .accentText => const Color(0xFF003C36),
        .validation => const Color(0xFF65EED8),
        .onPrimary => const Color(0xFFFFFFFF),
      },

    for (final $GlassColors color in $GlassColors.values)
      color.token: switch (color) {
        .primary => const Color(0x14FFFFFF),
        .secondary => const Color(0x0AFFFFFF),
        .border => const Color(0x26FFFFFF),
        .shadow => const Color(0x66000000),
        .neonBlue => const Color(0xFF60A5FA),
        .neonPurple => const Color(0xFFA78BFA),
        .neonPink => const Color(0xFFF472B6),
      },

    for (final $ComponentColors color in $ComponentColors.values)
      color.token: switch (color) {
        .cardGlass => const Color(0x14101827),
        .buttonGlass => const Color(0x1EFFFFFF),
        .navBar => const Color(0xCC0F172A),
      },
  };
}
