import 'package:flutter/widgets.dart';

/// A single scale multiplier applied to app-wide text plus a handful of the
/// highest-impact fixed-pixel shell dimensions (rail widths, top bar height,
/// artwork placeholder sizes), so Petal doesn't look tiny on a very large /
/// high-resolution display.
///
/// Why this is needed: Flutter lays out in *logical* pixels. On a laptop
/// with a HiDPI panel, the OS reports a devicePixelRatio > 1 and logical
/// pixels stay in a normal ~1440-wide range, so fixed dimensions look right.
/// But on a 4K monitor running at 100% OS scaling (common on Windows/Linux
/// desktops), devicePixelRatio is 1.0 and logical pixels map ~1:1 to
/// physical ones — the window is now ~3840 logical pixels wide, and a UI
/// whose dimensions were tuned for ~1440px (this app's approved design
/// baseline) ends up looking small relative to the screen.
///
/// This is a deliberately *bounded* fix: it scales text everywhere (via
/// MediaQuery's TextScaler) plus the shell chrome dimensions that make the
/// biggest visible difference, rather than multiplying literally every
/// padding/icon-size literal across every widget in the app — that would be
/// a much larger, higher-risk change to make without being able to compile
/// and see the result. If specific screens still feel too small after this,
/// they're straightforward to add to the same pattern one at a time.
class UiScale extends InheritedWidget {
  final double value;
  const UiScale({super.key, required this.value, required super.child});

  static double of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UiScale>()?.value ?? 1.0;
  }

  /// Baseline is 1440px (the approved design's target width) — below that,
  /// scale stays at 1.0 (no change from today). Above it, scale grows
  /// gently and is capped at 1.35x so it stays a readable boost rather than
  /// risking overflow in places that haven't been individually checked.
  static double forWidth(double width) {
    const baseline = 1440.0;
    if (width <= baseline) return 1.0;
    final scale = 1.0 + (width - baseline) / baseline * 0.5;
    return scale.clamp(1.0, 1.35);
  }

  @override
  bool updateShouldNotify(UiScale oldWidget) => value != oldWidget.value;
}
