import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Translucent control material. Its blur is clipped to the component bounds
/// so only the control's background needs filtering.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final double blur;
  final Color? tint;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(PetalTheme.radiusCard),
    ),
    this.padding,
    this.constraints,
    this.blur = 16,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? .32 : .11),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            constraints: constraints,
            decoration: BoxDecoration(
              color: tint ?? petal.colors.surface.withOpacity(dark ? .44 : .58),
              borderRadius: borderRadius,
              border: Border.all(
                color: Colors.white.withOpacity(dark ? .24 : .78),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(dark ? .17 : .42),
                  Colors.white.withOpacity(dark ? .045 : .12),
                  Colors.white.withOpacity(dark ? .015 : .035),
                ],
                stops: const [0, .48, 1],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A circular glass control for transport and top-level actions.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;
  final double iconSize;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.size = 48,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.petal.colors;
    return Tooltip(
      message: tooltip,
      child: GlassSurface(
        borderRadius: BorderRadius.circular(size / 2),
        tint: selected ? colors.accent.withOpacity(.30) : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                icon,
                size: iconSize,
                color: selected ? colors.ink : colors.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
