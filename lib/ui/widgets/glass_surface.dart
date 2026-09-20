import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Reusable readable glass. Blur is clipped to the component bounds and the
/// tint remains sufficiently opaque when the platform cannot render blur.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color? tint;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(PetalTheme.radiusCard),
    ),
    this.padding,
    this.blur = 22,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.24 : 0.08,
            ),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint ?? petal.colors.surface.withOpacity(0.78),
              borderRadius: borderRadius,
              border: Border.all(color: petal.colors.hairline2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(
                    Theme.of(context).brightness == Brightness.dark
                        ? 0.075
                        : 0.42,
                  ),
                  (tint ?? petal.colors.surface).withOpacity(0.68),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
