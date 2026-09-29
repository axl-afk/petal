import 'package:flutter/material.dart';

/// Petal's neutral glass palette with one restrained periwinkle accent.
/// Light/dark/auto remains the only personalization control so every
/// translucent layer keeps predictable contrast.
class AppColors {
  final Color ground;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color ink2; // secondary text
  final Color ink3; // tertiary / placeholder text
  final Color accent; // = ink, kept as its own token so components read intent, not implementation
  final Color
  accentInk; // text/icon color drawn on top of accent-filled controls
  final Color hairline;
  final Color hairline2;
  final Color
  good; // the one remaining "colored" token: the connected-source status dot
  final Color favorite;

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
    required this.favorite,
  });

  static const dark = AppColors(
    ground: Color(0xFF0B0B0D),
    surface: Color(0xFF19191C),
    surface2: Color(0xFF28282C),
    ink: Color(0xFFF5F5F7),
    ink2: Color(0xA3F5F5F7), // 64%
    ink3: Color(0x66F5F5F7), // 40%
    accent: Color(0xFFE8ECF4),
    accentInk: Color(0xFF17181B),
    hairline: Color(0x14FFFFFF),
    hairline2: Color(0x24FFFFFF),
    good: Color(0xFF34C77B),
    favorite: Color(0xFFFF375F),
  );

  static const light = AppColors(
    ground: Color(0xFFF2F4FA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFE8ECF6),
    ink: Color(0xFF17181B),
    ink2: Color(0xA3171821), // ~64%
    ink3: Color(0x66171821), // ~40%
    accent: Color(0xFF405BC7),
    accentInk: Color(0xFFFFFFFF),
    hairline: Color(0x14000000),
    hairline2: Color(0x24000000),
    good: Color(0xFF1F9D57),
    favorite: Color(0xFFD91740),
  );
}
