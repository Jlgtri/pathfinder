// ignore_for_file: public_member_api_docs

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mix/mix.dart';

import '../styles.dart';

/// A consistent page header, with optional back action and theme toggle.
///
/// Callbacks are passed from the route so this shared UI component doesn't
/// depend on Riverpod or GoRouter and can be reused in widget tests.
class RouteHeader extends StatelessWidget {
  const new({
    required this.isDark,
    required this.onToggleTheme,
    this.onBack,
    super.key,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) =>
      FlexBoxStyler()
          .row()
          .crossAxisAlignment(.center)
          .mainAxisAlignment(.spaceBetween)(
        children: <Widget>[
          if (onBack == null)
            BoxStyler().size(40, 40).alignment(.center)(
              child: IconStyler().size(22).color($Colors.primary())(
                icon: Icons.route_outlined,
              ),
            )
          else
            Tooltip(
              message: 'Back',
              child: PressableBox(
                onPress: onBack,
                style: _actionStyle,
                child: IconStyler().size(20).color($Colors.textPrimary())(
                  icon: Icons.arrow_back_rounded,
                ),
              ),
            ),
          BoxStyler().wrap(.flexible(flex: 1))(
            child: TextStyler()
                .style($TextStyles.brand())
                .textAlign(.center)('PATHFINDER'),
          ),
          Tooltip(
            message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            child: PressableBox(
              onPress: onToggleTheme,
              style: _actionStyle,
              child: IconStyler().size(20).color($Colors.textPrimary())(
                icon: isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
          ),
        ],
      );

  static final BoxStyler _actionStyle = BoxStyler()
      .size(40, 40)
      .color($Colors.input())
      .borderRadiusAll($Radius.compact())
      .alignment(.center)
      .onPressed(.scale(0.96));

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('isDark', isDark));
    properties.add(
      ObjectFlagProperty<VoidCallback>.has('onToggleTheme', onToggleTheme),
    );
    properties.add(ObjectFlagProperty<VoidCallback?>.has('onBack', onBack));
  }
}
