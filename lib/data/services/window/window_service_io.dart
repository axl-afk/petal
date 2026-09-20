import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop-only window chrome: a minimum window size (so the player can't
/// be dragged down to something unusably small — the actual "put a limit
/// on how small it can get" fix) and a rebuild nudge on macOS's native
/// fullscreen transitions.
///
/// This file is compiled on every dart:io platform, including Android/iOS
/// — window_manager itself declares no Android/iOS platform implementation,
/// so it's a harmless Dart-level import there, but every call below is
/// still explicitly gated behind [_isDesktop] rather than relying on that
/// alone, since calling a plugin method with no registered platform
/// implementation throws a MissingPluginException.
class WindowService {
  static bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// 380x560 is the floor: small enough to still feel like a compact
  /// player, large enough that the top bar, a few track rows, and the mini
  /// player all stay legible rather than overlapping — every screen in
  /// this app already has a working single-column ("mobile") layout below
  /// Breakpoints.mobile (900px), so a narrow desktop window at this floor
  /// still renders the same layout a phone would, just never smaller than
  /// this actually-readable size.
  static const minimumSize = Size(380, 560);

  /// Bumped on every desktop window resize / fullscreen enter-or-leave
  /// event. AppShell's LayoutBuilder already rebuilds on its own whenever
  /// the window's constraints change — Flutter's macOS embedder propagates
  /// native-fullscreen transitions through the same window-metrics path as
  /// any other resize (verified against the engine's
  /// FlutterViewController.mm), so this isn't working around a known
  /// engine bug. It exists purely as cheap, harmless insurance for the one
  /// transition specifically reported as visually wrong — nothing here
  /// depends on it firing for correctness.
  static final ValueNotifier<int> rebuildTick = ValueNotifier<int>(0);

  static bool _initialized = false;
  static bool _mobileFullscreen = false;

  static Future<void> ensureInitialized() async {
    if (!_isDesktop || _initialized) return;
    _initialized = true;
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(minimumSize);
    windowManager.addListener(_RebuildTickListener());
  }

  static Future<void> toggleFullscreen() async {
    if (_isDesktop) {
      final fullscreen = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!fullscreen);
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      _mobileFullscreen = !_mobileFullscreen;
      await SystemChrome.setEnabledSystemUIMode(
        _mobileFullscreen
            ? SystemUiMode.immersiveSticky
            : SystemUiMode.edgeToEdge,
      );
    }
  }
}

class _RebuildTickListener with WindowListener {
  @override
  void onWindowResize() => WindowService.rebuildTick.value++;

  @override
  void onWindowEnterFullScreen() => WindowService.rebuildTick.value++;

  @override
  void onWindowLeaveFullScreen() => WindowService.rebuildTick.value++;
}
