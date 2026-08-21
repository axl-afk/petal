import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Carries Petal's design tokens through the widget tree as a Material
/// ThemeExtension, so any widget can do:
///   final petal = context.petal;
/// and get typed access to both the flat color tokens and the derived text
/// styles, instead of re-deriving colors ad hoc per screen.
class PetalTheme extends ThemeExtension<PetalTheme> {
  final AppColors colors;
  final AppTextStyles text;

  const PetalTheme({required this.colors, required this.text});

  static const double railWidth = 226;
  static const double rightRailWidth = 292;
  static const double topBarHeight = 64;
  static const double radiusPill = 999;
  static const double radiusCard = 16;
  static const double radiusHero = 20;

  @override
  PetalTheme copyWith({AppColors? colors, AppTextStyles? text}) =>
      PetalTheme(colors: colors ?? this.colors, text: text ?? this.text);

  @override
  PetalTheme lerp(ThemeExtension<PetalTheme>? other, double t) {
    if (other is! PetalTheme) return this;
    return t < 0.5 ? this : other;
  }
}

extension PetalThemeContext on BuildContext {
  PetalTheme get petal => Theme.of(this).extension<PetalTheme>()!;
}

ThemeData buildPetalThemeData(AppColors c, Brightness brightness) {
  final textStyles = AppTextStyles(c);
  final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();

  return base.copyWith(
    brightness: brightness,
    scaffoldBackgroundColor: c.ground,
    canvasColor: c.ground,
    primaryColor: c.accent,
    colorScheme: (brightness == Brightness.dark ? const ColorScheme.dark() : const ColorScheme.light())
        .copyWith(
      primary: c.accent,
      onPrimary: c.accentInk,
      surface: c.surface,
      onSurface: c.ink,
      secondary: c.accent,
    ),
    dividerColor: c.hairline,
    splashFactory: InkRipple.splashFactory,
    highlightColor: c.hairline,
    hoverColor: c.hairline,
    textTheme: base.textTheme.apply(
      bodyColor: c.ink,
      displayColor: c.ink,
    ),
    iconTheme: IconThemeData(color: c.ink2, size: 20),
    extensions: [PetalTheme(colors: c, text: textStyles)],
  );
}

final ThemeData petalLightTheme = buildPetalThemeData(AppColors.light, Brightness.light);
final ThemeData petalDarkTheme = buildPetalThemeData(AppColors.dark, Brightness.dark);
