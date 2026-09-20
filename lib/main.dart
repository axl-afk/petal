import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'data/services/prefs_service.dart';
import 'data/services/window/window_service.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop-only (no-ops on Android/iOS/web — see WindowService) — sets the
  // minimum window size and starts listening for fullscreen transitions,
  // before runApp() so the constraint is in place from the very first
  // frame rather than racing a resize the user could trigger immediately.
  await WindowService.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'app.petal.playback',
    androidNotificationChannelName: 'Petal playback',
    androidNotificationOngoing: true,
  );

  // Standard pairing for just_audio: tells the OS this is a music app, so
  // headphone unplug pauses playback, other music apps duck/stop
  // appropriately, and iOS background audio behaves correctly.
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  final prefs = await PrefsService.create();

  runApp(
    ProviderScope(
      overrides: [
        prefsServiceProvider.overrideWithValue(prefs),
      ],
      child: const PetalApp(),
    ),
  );
}
