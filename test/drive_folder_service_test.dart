import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:petal/data/services/drive_folder_service.dart';

void main() {
  test(
    'selected Drive folder imports supported audio across nested pages',
    () async {
      final visited = <String>[];
      final service = DriveFolderService(
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer token');
          final folder = RegExp("'([^']+)' in parents")
              .firstMatch(request.url.queryParameters['q']!)!
              .group(1)!;
          visited.add(folder);
          if (folder == 'root' &&
              request.url.queryParameters['pageToken'] == null) {
            return http.Response(
              jsonEncode({
                'nextPageToken': 'next',
                'files': [
                  {
                    'id': 'child',
                    'name': 'Albums',
                    'mimeType': 'application/vnd.google-apps.folder',
                  },
                  {
                    'id': 'first',
                    'name': 'गाना.flac',
                    'mimeType': 'audio/flac',
                  },
                ],
              }),
              200,
            );
          }
          if (folder == 'root') {
            return http.Response(
              jsonEncode({
                'files': [
                  {'id': 'skip', 'name': 'notes.txt', 'mimeType': 'text/plain'},
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'second', 'name': 'বাংলা.mp3', 'mimeType': 'audio/mpeg'},
              ],
            }),
            200,
          );
        }),
      );

      final files = await service.listAudioFiles('token', 'root');
      expect(files.map((f) => f.name), ['गाना.flac', 'বাংলা.mp3']);
      expect(visited, ['root', 'root', 'child']);
    },
  );
}
