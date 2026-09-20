import '../db/tables.dart';

/// Provider-neutral metadata returned by a cloud account scan.
class CloudAudioItem {
  final TrackSourceType provider;
  final String providerItemId;
  final String name;
  final String streamUri;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime? modifiedAt;
  final String? artworkUrl;
  final String? metadataTitle;
  final String? artist;
  final String? album;
  final String? genre;
  final int? durationMs;

  const CloudAudioItem({
    required this.provider,
    required this.providerItemId,
    required this.name,
    required this.streamUri,
    this.mimeType,
    this.sizeBytes,
    this.modifiedAt,
    this.artworkUrl,
    this.metadataTitle,
    this.artist,
    this.album,
    this.genre,
    this.durationMs,
  });

  String get stableOrigin => 'petal-cloud://${provider.name}/$providerItemId';

  String get title {
    if (metadataTitle != null && metadataTitle!.trim().isNotEmpty) {
      return metadataTitle!.trim();
    }
    if (name.trim().isEmpty) return 'Untitled Track';
    final dot = name.lastIndexOf('.');
    final stem = (dot > 0 ? name.substring(0, dot) : name).trim();
    if ((artist == null || artist!.trim().isEmpty) && stem.contains(' - ')) {
      return stem.substring(stem.indexOf(' - ') + 3).trim();
    }
    return stem;
  }

  String get resolvedArtist {
    if (artist != null && artist!.trim().isNotEmpty) return artist!.trim();
    final dot = name.lastIndexOf('.');
    final stem = (dot > 0 ? name.substring(0, dot) : name).trim();
    final separator = stem.indexOf(' - ');
    return separator > 0 ? stem.substring(0, separator).trim() : 'Unknown Artist';
  }
}
