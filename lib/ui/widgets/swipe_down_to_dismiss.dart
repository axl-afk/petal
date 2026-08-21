import 'package:flutter/material.dart';

/// Wraps [child] so a downward drag past a distance threshold calls
/// [onDismiss] — the "sliding down the player folds it back down" gesture,
/// with the content visibly following the finger/pointer during the drag
/// (and animating back to place if released early) rather than an instant
/// jump. Used by NowPlayingScreen (drag down -> back to whatever section
/// was showing underneath, mini player reappears — see AppShell, which
/// only hides MiniPlayer while AppSection.nowPlaying is active) and
/// LyricsScreen (drag down -> back to Now Playing).
///
/// Deliberately distance-only (no fling/velocity threshold): the existing
/// down-arrow IconButton on both screens is the reliable, always-available
/// way to go back, so this only needs to feel good for a clear, deliberate
/// drag — not chase edge cases around fast, short flicks — while both
/// screens' content is a fixed, non-scrolling layout (Column + Spacer),
/// so there's no competing vertical-scroll gesture to disambiguate against.
class SwipeDownToDismiss extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const SwipeDownToDismiss({super.key, required this.child, required this.onDismiss});

  @override
  State<SwipeDownToDismiss> createState() => _SwipeDownToDismissState();
}

class _SwipeDownToDismissState extends State<SwipeDownToDismiss> with SingleTickerProviderStateMixin {
  static const _dismissDistance = 120.0;
  static const _dragCap = 400.0;

  late final AnimationController _snapController;
  Animation<double> _snapAnimation = const AlwaysStoppedAnimation(0);
  double _dragExtent = 0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))
      ..addListener(() => setState(() => _dragExtent = _snapAnimation.value));
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_snapController.isAnimating) return;
    setState(() => _dragExtent = (_dragExtent + details.delta.dy).clamp(0.0, _dragCap));
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragExtent >= _dismissDistance) {
      widget.onDismiss();
      // The section switch this triggers normally unmounts this widget —
      // reset defensively in case a caller ever reuses it without that.
      setState(() => _dragExtent = 0);
      return;
    }
    _snapAnimation = Tween<double>(begin: _dragExtent, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
    );
    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragExtent / _dragCap).clamp(0.0, 1.0);
    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Transform.translate(
        offset: Offset(0, _dragExtent),
        child: Opacity(
          opacity: 1 - progress * 0.4,
          child: widget.child,
        ),
      ),
    );
  }
}
