import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/services/prefs_service.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
