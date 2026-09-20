import 'dart:convert';

import 'package:http/http.dart' as http;

import '../db/tables.dart';
import '../models/cloud_audio_item.dart';
import 'local_file_types.dart';

class CloudLibraryException implements Exception {
  final String message;
  const CloudLibraryException(this.message);
  @override
  String toString() => message;
}

/// Discovers audio through the official Google Drive and Microsoft Graph
/// APIs. Results are provider-neutral and use stable item IDs; temporary
/// download URLs are never used as database identity.
class CloudLibraryService {
  final http.Client _client;
  CloudLibraryService({http.Client? client})
    : _client = client ?? http.Client();

  Future<List<CloudAudioItem>> scanGoogleDrive(
    String accessToken, {
    void Function(int discovered)? onProgress,
  }) async {
    final items = <CloudAudioItem>[];
    String? pageToken;
    do {
      final uri = Uri.parse('https://www.googleapis.com/drive/v3/files')
          .replace(
            queryParameters: {
              'q': 'trashed = false',
              'pageSize': '1000',
              'fields': 'nextPageToken,files(id,name,mimeType,size,modifiedTime,thumbnailLink)',
              if (pageToken != null) 'pageToken': pageToken,
            },
          );
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(const Duration(seconds: 30));
      _requireSuccess(response, 'Google Drive');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      for (final raw in (body['files'] as List<dynamic>? ?? const [])) {
        final file = raw as Map<String, dynamic>;
        final id = file['id'] as String?;
        final name = file['name'] as String?;
        final mime = file['mimeType'] as String?;
        if (id == null || name == null || !_looksLikeAudio(name, mime))
          continue;
        items.add(
          CloudAudioItem(
            provider: TrackSourceType.googleDrive,
            providerItemId: id,
            name: name,
            streamUri:
                'https://www.googleapis.com/drive/v3/files/$id?alt=media',
            mimeType: mime,
            sizeBytes: int.tryParse(file['size']?.toString() ?? ''),
            modifiedAt: DateTime.tryParse(
              file['modifiedTime']?.toString() ?? '',
            ),
            artworkUrl: file['thumbnailLink'] as String?,
          ),
        );
        onProgress?.call(items.length);
      }
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return items;
  }

  Future<List<CloudAudioItem>> scanOneDrive(
    String accessToken, {
    void Function(int discovered)? onProgress,
  }) async {
    final items = <CloudAudioItem>[];
    Uri? next = Uri.parse(
      'https://graph.microsoft.com/v1.0/me/drive/root/delta?'
      r'$select=id,name,size,file,audio,lastModifiedDateTime&$expand=thumbnails',
    );
    while (next != null) {
      final response = await _client
          .get(next, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(const Duration(seconds: 30));
      _requireSuccess(response, 'OneDrive');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      for (final raw in (body['value'] as List<dynamic>? ?? const [])) {
        final file = raw as Map<String, dynamic>;
        if (file['deleted'] != null || file['folder'] != null) continue;
        final id = file['id'] as String?;
        final name = file['name'] as String?;
        final fileFacet = file['file'] as Map<String, dynamic>?;
        final audio = file['audio'] as Map<String, dynamic>?;
        final mime = fileFacet?['mimeType'] as String?;
        if (id == null || name == null || !_looksLikeAudio(name, mime))
          continue;
        items.add(
          CloudAudioItem(
            provider: TrackSourceType.oneDrive,
            providerItemId: id,
            name: name,
            streamUri:
                'https://graph.microsoft.com/v1.0/me/drive/items/$id/content',
            mimeType: mime,
            sizeBytes: (file['size'] as num?)?.toInt(),
            modifiedAt: DateTime.tryParse(
              file['lastModifiedDateTime']?.toString() ?? '',
            ),
            metadataTitle: audio?['title'] as String?,
            artist: (audio?['artist'] ?? audio?['albumArtist']) as String?,
            album: audio?['album'] as String?,
            genre: audio?['genre'] as String?,
            durationMs: (audio?['duration'] as num?)?.toInt(),
            artworkUrl: _oneDriveThumbnail(file),
          ),
        );
        onProgress?.call(items.length);
      }
      final nextLink = body['@odata.nextLink'] as String?;
      next = nextLink == null ? null : Uri.tryParse(nextLink);
    }
    return items;
  }

  String? _oneDriveThumbnail(Map<String, dynamic> file) {
    final sets = file['thumbnails'] as List<dynamic>?;
    if (sets == null || sets.isEmpty) return null;
    final first = sets.first as Map<String, dynamic>?;
    for (final size in const ['large', 'medium', 'small']) {
      final item = first?[size] as Map<String, dynamic>?;
      final url = item?['url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  bool _looksLikeAudio(String name, String? mimeType) {
    if (mimeType?.toLowerCase().startsWith('audio/') == true) return true;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return kAudioExtensions.contains(name.substring(dot + 1).toLowerCase());
  }

  void _requireSuccess(http.Response response, String provider) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CloudLibraryException(
        '$provider access expired or was declined. Sign out, sign in again, and allow file access.',
      );
    }
    if (response.statusCode == 429) {
      throw CloudLibraryException(
        '$provider is rate-limiting this scan. Wait a moment and retry.',
      );
    }
    throw CloudLibraryException(
      '$provider scan failed (HTTP ${response.statusCode}).',
    );
  }
}
