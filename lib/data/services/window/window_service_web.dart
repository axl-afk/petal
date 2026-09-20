import 'package:flutter/widgets.dart';

/// Web stub — there's no OS window to size or listen to fullscreen events
/// on inside a browser tab. rebuildTick still exists (and simply never
/// changes) so AppShell can wrap it in the same ValueListenableBuilder on
/// every platform without an extra conditional.
class WindowService {
  static final ValueNotifier<int> rebuildTick = ValueNotifier<int>(0);

  static Future<void> ensureInitialized() async {}

  static Future<void> toggleFullscreen() async {}
}
