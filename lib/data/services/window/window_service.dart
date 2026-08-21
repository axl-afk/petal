// Desktop window chrome (minimum size + fullscreen-transition rebuild
// nudge — see window_service_io.dart) needs window_manager, which itself
// needs dart:io-level platform channels that don't exist on web. Same
// conditional-export pattern as local_file_service.dart / drift's
// connection.dart: the real implementation everywhere dart:io is
// available, a no-op stub specifically on web.
export 'window_service_web.dart' if (dart.library.io) 'window_service_io.dart';
