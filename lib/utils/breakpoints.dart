/// Mirrors the responsive breakpoints from the approved HTML prototype:
/// >=1240 full 3-column layout, 900-1239 rail+main (right rail hidden),
/// <900 single column (rail becomes a bottom/drawer nav).
class Breakpoints {
  static const double tablet = 1240;
  static const double mobile = 900;

  static bool isDesktop(double width) => width >= tablet;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isMobile(double width) => width < mobile;
}
