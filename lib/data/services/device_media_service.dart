import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceAudioItem {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String contentUri;
  final String? artworkUri;

  const DeviceAudioItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.contentUri,
    this.artworkUri,
  });
}

/// Android MediaStore bridge. iOS intentionally uses its document picker:
/// third-party iOS apps cannot enumerate arbitrary device audio files.
class DeviceMediaService {
  static const _channel = MethodChannel('app.petal/device_media');

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<DeviceAudioItem>> scanAudio() async {
    if (!supported) return const [];
    final rows =
        await _channel.invokeListMethod<dynamic>('scanAudio') ?? const [];
    return rows.whereType<Map<dynamic, dynamic>>().map((row) {
      return DeviceAudioItem(
        id: row['id'].toString(),
        title: (row['title'] as String?)?.trim().isNotEmpty == true
            ? row['title'] as String
            : 'Untitled Track',
        artist: (row['artist'] as String?)?.trim().isNotEmpty == true
            ? row['artist'] as String
            : 'Unknown Artist',
        album: row['album'] as String? ?? '',
        durationMs: (row['durationMs'] as num?)?.toInt() ?? 0,
        contentUri: row['contentUri'] as String,
        artworkUri: row['artworkUri'] as String?,
      );
    }).toList();
  }

  Future<Uint8List?> loadArtwork(String contentUri) async {
    if (!supported || !contentUri.startsWith('content://')) return null;
    return _channel.invokeMethod<Uint8List>(
      'loadArtwork',
      {'uri': contentUri},
    );
  }
}
