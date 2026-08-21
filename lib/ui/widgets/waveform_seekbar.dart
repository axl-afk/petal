import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The "wave" seek bar from the approved design: a static, deterministic
/// bar pattern (seeded from the track id, so it doesn't jitter every
/// rebuild) with a two-tone fill that advances with playback progress.
/// Painted once per frame via CustomPainter instead of animating dozens of
/// individual bar widgets, which is what keeps this smooth while
/// `positionStream` ticks many times a second.
class WaveformSeekBar extends StatelessWidget {
  final String seed;
  final double progress; // 0..1
  final ValueChanged<double> onSeekFraction;
  final Color filledColor;
  final Color unfilledColor;
  final double height;

  const WaveformSeekBar({
    super.key,
    required this.seed,
    required this.progress,
    required this.onSeekFraction,
    required this.filledColor,
    required this.unfilledColor,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void handle(Offset local) {
          final frac = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
          onSeekFraction(frac);
        }

        return GestureDetector(
          onTapDown: (d) => handle(d.localPosition),
          onHorizontalDragUpdate: (d) => handle(d.localPosition),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                seed: seed,
                progress: progress.clamp(0.0, 1.0),
                filled: filledColor,
                unfilled: unfilledColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final String seed;
  final double progress;
  final Color filled;
  final Color unfilled;

  _WaveformPainter({required this.seed, required this.progress, required this.filled, required this.unfilled});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final barCount = (size.width / 4).floor().clamp(20, 200);
    final barWidth = size.width / barCount;
    final rand = math.Random(seed.hashCode);
    final progressX = size.width * progress;

    for (var i = 0; i < barCount; i++) {
      final h = (0.22 + rand.nextDouble() * 0.78) * size.height;
      final x = i * barWidth;
      final rect = Rect.fromLTWH(x + barWidth * 0.18, (size.height - h) / 2, barWidth * 0.64, h);
      final paint = Paint()..color = x < progressX ? filled : unfilled;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.seed != seed || oldDelegate.filled != filled;
}
