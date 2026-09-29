import 'dart:convert';

import 'package:http/http.dart' as http;

import 'local_file_types.dart' show kAudioExtensions;

class DriveFolderException implements Exception {
  final String message;
  DriveFolderException(this.message);
  @override
  String toString() => message;
}

class DriveFolderFile {
  final String id;
  final String name;
  const DriveFolderFile({required this.id, required this.name});
}

/// Lists audio files within a Google Drive folder the
/// signed-in account can see, given the folder's id (parsed from a pasted
/// folder share link — see LinkResolverService.driveFolderId).
///
/// Unlike a single-file link (a pure URL rewrite — no OAuth involved at
/// all, see LinkResolverService's own doc comment), listing what's *inside*
/// a folder genuinely requires calling the Drive API, which is why folder
/// import is Google-sign-in-only: there's no public "list files in this
/// shared folder" URL the way there is for downloading one already-known
/// file id. This needs the broader `drive.readonly` scope (read access to
/// the whole Drive the account can see) rather than the narrow
/// `drive.appdata` scope the library-backup feature uses — a meaningfully
/// bigger permission grant, flagged in README's sign-in section.
///
/// Includes child folders, with a bound to prevent accidental huge scans.
class DriveFolderService {
  static const _filesUrl = 'https://www.googleapis.com/drive/v3/files';

  final http.Client _client;
  DriveFolderService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<DriveFolderFile>> listAudioFiles(
    String accessToken,
    String folderId,
  ) async {
    final all = <DriveFolderFile>[];
    final pending = <String>[folderId];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current)) continue;
      if (visited.length > 500) {
        throw DriveFolderException(
          'This folder contains more than 500 subfolders. Choose a smaller folder.',
        );
      }
      String? pageToken;
      do {
        final uri = Uri.parse(_filesUrl).replace(
          queryParameters: {
            'q': "'$current' in parents and trashed = false",
            'fields': 'nextPageToken, files(id, name, mimeType)',
            'pageSize': '200',
            'supportsAllDrives': 'true',
            'includeItemsFromAllDrives': 'true',
            if (pageToken != null) 'pageToken': pageToken,
          },
        );

        final res = await _client
            .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
            .timeout(const Duration(seconds: 20));

        if (res.statusCode == 403 || res.statusCode == 404) {
          throw DriveFolderException(
            "Couldn't read that folder — make sure it's actually shared with this Google "
            "account (Anyone with the link, or shared directly with you), and that Drive "
            "access wasn't declined during sign-in.",
          );
        }
        if (res.statusCode != 200) {
          throw DriveFolderException(
            'Google Drive returned ${res.statusCode} listing that folder.',
          );
        }

        final json =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final items = (json['files'] as List<dynamic>?) ?? const [];
        for (final item in items) {
          final map = item as Map<String, dynamic>;
          final id = map['id'] as String?;
          final name = map['name'] as String?;
          if (id == null || name == null) continue;
          if (map['mimeType'] == 'application/vnd.google-apps.folder') {
            pending.add(id);
            continue;
          }
          final ext = name.contains('.')
              ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
              : '';
          if (kAudioExtensions.contains(ext)) {
            all.add(DriveFolderFile(id: id, name: name));
          }
        }
        pageToken = json['nextPageToken'] as String?;
      } while (pageToken != null && pageToken.isNotEmpty);
    }

    return all;
  }

  /// Looks up a single Drive file's real name by id — used when a user
  /// pastes a single-file share link without typing a title (see
  /// LibraryController.connectLink), so the track shows its actual
  /// filename instead of a generic "Untitled Track". Same `drive.readonly`
  /// scope [listAudioFiles] above already needs — no extra permission
  /// grant. Best-effort: returns null on any failure (not signed in, no
  /// network, file not accessible, deleted) rather than throwing, so a
  /// failed lookup just falls back to whatever title the caller already
  /// had rather than blocking the whole "add a source" action over a
  /// cosmetic detail.
  Future<String?> getFileName(String accessToken, String fileId) async {
    final uri = Uri.parse('$_filesUrl/$fileId')
        .replace(queryParameters: {'fields': 'name'});
    try {
      final res = await _client
          .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return json['name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
