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

  const CloudAudioItem({
    required this.provider,
    required this.providerItemId,
    required this.name,
    required this.streamUri,
    this.mimeType,
    this.sizeBytes,
    this.modifiedAt,
    this.artworkUrl,
  });

  String get stableOrigin => 'petal-cloud://${provider.name}/$providerItemId';

  String get title {
    final dot = name.lastIndexOf('.');
    return (dot > 0 ? name.substring(0, dot) : name).trim();
  }
}
