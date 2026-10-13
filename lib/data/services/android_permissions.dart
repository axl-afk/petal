import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android's device library and playback notification need different grants.
/// A system file picker on Android and iOS manages access to selected files.
class AndroidPermissions {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> requestAudioLibrary() async {
    if (!supported) return true;
    if ((await Permission.audio.request()).isGranted) return true;
    // READ_EXTERNAL_STORAGE applies through Android 12; the plugin resolves
    // this to denied without another dialog on newer Android versions.
    return (await Permission.storage.request()).isGranted;
  }

  static Future<bool> requestPlaybackNotifications() async {
    if (!supported) return true;
    return (await Permission.notification.request()).isGranted;
  }
}
