import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cloud_backup_service.dart' show CloudBackupException;

/// Stores Petal's portable metadata in the OneDrive application folder.
/// Files.ReadWrite.AppFolder limits writes to this app-owned location.
class MicrosoftBackupService {
  static const _contentUrl =
      'https://graph.microsoft.com/v1.0/me/drive/special/approot:/petal_library_v2.json:/content';

  final http.Client _client;
  MicrosoftBackupService({http.Client? client})
    : _client = client ?? http.Client();

  Future<Map<String, dynamic>?> pull(String accessToken) async {
    final response = await _client
        .get(
          Uri.parse(_contentUrl),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw CloudBackupException(
        'OneDrive returned ${response.statusCode} downloading sync data.',
      );
    }
    if (response.body.trim().isEmpty) return null;
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw CloudBackupException('The OneDrive sync file is not valid JSON.');
    }
  }

  Future<void> push(String accessToken, Map<String, dynamic> snapshot) async {
    final response = await _client
        .put(
          Uri.parse(_contentUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(snapshot),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CloudBackupException(
        'OneDrive returned ${response.statusCode} uploading sync data.',
      );
    }
  }
}
