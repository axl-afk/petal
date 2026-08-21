import 'package:flutter/material.dart';

/// Petal's monochrome color tokens, ported 1:1 from the approved HTML/CSS
/// design prototype (`--ground`, `--surface`, `--ink`, `--accent`, etc).
/// There is deliberately no user-selectable accent color — the "accent" is
/// always just the theme's own foreground ink, so light/dark/auto is the
/// only personalization option, per the approved design.
class AppColors {
  final Color ground;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color ink2; // secondary text
  final Color ink3; // tertiary / placeholder text
  final Color accent; // = ink, kept as its own token so components read intent, not implementation
  final Color accentInk; // text/icon color drawn on top of accent-filled controls
  final Color hairline;
  final Color hairline2;
  final Color good; // the one remaining "colored" token: the connected-source status dot

  const AppColors({
    required this.ground,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accent,
    required this.accentInk,
    required this.hairline,
    required this.hairline2,
    required this.good,
  });

  static const dark = AppColors(
    ground: Color(0xFF0A0A0B),
    surface: Color(0xFF17171A),
    surface2: Color(0xFF1E1E22),
    ink: Color(0xFFF5F5F7),
    ink2: Color(0xA3F5F5F7), // 64%
    ink3: Color(0x66F5F5F7), // 40%
    accent: Color(0xFFFFFFFF),
    accentInk: Color(0xFF101012),
    hairline: Color(0x14FFFFFF),
    hairline2: Color(0x24FFFFFF),
    good: Color(0xFF34C77B),
  );

  static const light = AppColors(
    ground: Color(0xFFF6F6F7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF0F0F2),
    ink: Color(0xFF17181B),
    ink2: Color(0xA3171821), // ~64%
    ink3: Color(0x66171821), // ~40%
    accent: Color(0xFF17181B),
    accentInk: Color(0xFFFFFFFF),
    hairline: Color(0x14000000),
    hairline2: Color(0x24000000),
    good: Color(0xFF1F9D57),
  );
}
