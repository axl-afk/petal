import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Slow, low-contrast liquid shapes that give the glass panes something to
/// refract. The painter is ignored when the platform requests reduced motion.
class AnimatedGlassBackdrop extends StatefulWidget {
  const AnimatedGlassBackdrop({super.key});

  @override
  State<AnimatedGlassBackdrop> createState() => _AnimatedGlassBackdropState();
}

class _AnimatedGlassBackdropState extends State<AnimatedGlassBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = .18;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petal.colors;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _DropletPainter(
              phase: _controller.value * math.pi * 2,
              accent: colors.accent,
              surface: colors.surface2,
              dark: Theme.of(context).brightness == Brightness.dark,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _DropletPainter extends CustomPainter {
  final double phase;
  final Color accent;
  final Color surface;
  final bool dark;

  const _DropletPainter({
    required this.phase,
    required this.accent,
    required this.surface,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shortest = math.min(size.width, size.height);
    final drops = <({Offset center, double radius, Color color})>[
      (
        center: Offset(
          size.width * (.18 + math.sin(phase) * .035),
          size.height * (.20 + math.cos(phase * .8) * .045),
        ),
        radius: shortest * .24,
        color: accent,
      ),
      (
        center: Offset(
          size.width * (.72 + math.cos(phase * .72) * .045),
          size.height * (.24 + math.sin(phase * .64) * .04),
        ),
        radius: shortest * .29,
        color: surface,
      ),
      (
        center: Offset(
          size.width * (.58 + math.sin(phase * .55) * .055),
          size.height * (.80 + math.cos(phase * .7) * .03),
        ),
        radius: shortest * .20,
        color: accent,
      ),
    ];

    for (final drop in drops) {
      final paint = Paint()
        ..color = drop.color.withOpacity(dark ? .12 : .10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shortest * .06);
      canvas.drawCircle(drop.center, drop.radius, paint);
      canvas.drawCircle(
        drop.center.translate(-drop.radius * .18, -drop.radius * .2),
        drop.radius * .42,
        Paint()
          ..color = Colors.white.withOpacity(dark ? .025 : .13)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shortest * .035),
      );
    }
  }

  @override
  bool shouldRepaint(_DropletPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.accent != accent ||
      oldDelegate.surface != surface ||
      oldDelegate.dark != dark;
}
