import 'dart:math' as math;

/// Collection artwork follows the available pane width rather than a fixed
/// four-column desktop grid. All dimensions are logical pixels.
class CollectionLayout {
  static const double spacing = 16;

  static int columns(double width) {
    if (width < 520) return 2;
    final ideal = width >= 2200
        ? 400.0
        : width >= 1100
        ? 275.0
        : 220.0;
    return (width / ideal).floor().clamp(2, 8);
  }

  static double cardWidth(double width) {
    final count = columns(width);
    return math.max(1, (width - (count - 1) * spacing) / count);
  }

  static double shelfWidth(double viewportWidth) {
    if (viewportWidth >= 2400) return 370;
    if (viewportWidth >= 1400) return 285;
    if (viewportWidth >= 900) return 230;
    if (viewportWidth >= 600) return 195;
    return 164;
  }
}
