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
  final ValueNotifier<double> _dragExtent = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))
      ..addListener(() => _dragExtent.value = _snapAnimation.value);
  }

  @override
  void dispose() {
    _snapController.dispose();
    _dragExtent.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_snapController.isAnimating) return;
    _dragExtent.value = (_dragExtent.value + details.delta.dy).clamp(0.0, _dragCap);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragExtent.value >= _dismissDistance) {
      widget.onDismiss();
      // The section switch this triggers normally unmounts this widget —
      // reset defensively in case a caller ever reuses it without that.
      _dragExtent.value = 0;
      return;
    }
    _snapAnimation = Tween<double>(begin: _dragExtent.value, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
    );
    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: ValueListenableBuilder<double>(
        valueListenable: _dragExtent,
        child: widget.child,
        builder: (context, extent, child) => Transform.translate(
          offset: Offset(0, extent),
          child: Opacity(
            opacity: 1 - (extent / _dragCap).clamp(0.0, 1.0) * .4,
            child: child,
          ),
        ),
      ),
    );
  }
}
