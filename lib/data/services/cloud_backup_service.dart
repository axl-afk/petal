import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown when a Drive API call fails, with enough detail to show the user
/// (or log) something more useful than a generic "sync failed".
class CloudBackupException implements Exception {
  final String message;
  CloudBackupException(this.message);
  @override
  String toString() => message;
}

/// Stores Petal's library backup (see LibrarySyncService) as a single JSON
/// file in the signed-in Google account's own Drive "Application Data"
/// folder — a hidden folder, invisible in the user's normal Drive UI, that
/// only this app can see or touch (that's what the `drive.appdata` scope
/// requested in google_auth_service.dart grants, nothing broader). This is
/// the whole "no server" mechanism: Petal never runs its own database of
/// who-owns-what, it just reads/writes one small file in a place the
/// user's own Google account already provides for free.
///
/// Talks to the raw Drive REST API v3 directly over `http` rather than
/// pulling in the `googleapis`/`googleapis_auth` packages — the handful of
/// calls needed here (find-by-name, get-content, create, update-content)
/// are plain HTTP requests, so a full client SDK would be a lot of extra
/// weight for very little. This is, honestly, the single least-tested
/// integration in the whole project — it was written against the Drive API
/// v3 reference docs with no real Google account available to sign in with
/// and exercise it end-to-end. If a sync fails with an error mentioning
/// Drive/HTTP status codes, paste it back.
class CloudBackupService {
  static const _fileName = 'petal_library_v1.json';
  static const _filesUrl = 'https://www.googleapis.com/drive/v3/files';
  static const _uploadUrl = 'https://www.googleapis.com/upload/drive/v3/files';

  final http.Client _client;
  CloudBackupService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  Future<String?> _findFileId(String accessToken) async {
    final uri = Uri.parse(_filesUrl).replace(queryParameters: {
      'spaces': 'appDataFolder',
      'q': "name = '$_fileName' and trashed = false",
      'fields': 'files(id)',
      'pageSize': '1',
    });
    final res = await _client.get(uri, headers: _headers(accessToken)).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw CloudBackupException('Google Drive returned ${res.statusCode} looking up the backup file.');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final files = (json['files'] as List<dynamic>?) ?? const [];
    if (files.isEmpty) return null;
    return (files.first as Map<String, dynamic>)['id'] as String?;
  }

  /// Returns the parsed backup, or null if this account has never backed
  /// one up before (first sign-in, on any device) or the stored file was
  /// corrupt/empty (treated the same as "no backup yet" so a bad write
  /// never blocks sync forever — the next push just overwrites it).
  Future<Map<String, dynamic>?> pull(String accessToken) async {
    final fileId = await _findFileId(accessToken);
    if (fileId == null) return null;

    final uri = Uri.parse('$_filesUrl/$fileId').replace(queryParameters: {'alt': 'media'});
    final res = await _client.get(uri, headers: _headers(accessToken)).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw CloudBackupException('Google Drive returned ${res.statusCode} downloading the backup file.');
    }
    if (res.body.trim().isEmpty) return null;
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> push(String accessToken, Map<String, dynamic> snapshot) async {
    final body = jsonEncode(snapshot);
    final existingId = await _findFileId(accessToken);

    if (existingId == null) {
      await _create(accessToken, body);
    } else {
      await _update(accessToken, existingId, body);
    }
  }

  Future<void> _create(String accessToken, String jsonBody) async {
    final createUri = Uri.parse(_uploadUrl).replace(queryParameters: {'uploadType': 'multipart'});
    final boundary = 'petal-${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': _fileName,
      'parents': ['appDataFolder'],
    });
    final multipartBody = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json\r\n\r\n'
        '$jsonBody\r\n'
        '--$boundary--';

    final res = await _client
        .post(
          createUri,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: multipartBody,
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw CloudBackupException('Google Drive returned ${res.statusCode} creating the backup file.');
    }
  }

  Future<void> _update(String accessToken, String fileId, String jsonBody) async {
    final updateUri = Uri.parse('$_uploadUrl/$fileId').replace(queryParameters: {'uploadType': 'media'});
    final res = await _client
        .patch(updateUri, headers: _headers(accessToken), body: jsonBody)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw CloudBackupException('Google Drive returned ${res.statusCode} updating the backup file.');
    }
  }
}
