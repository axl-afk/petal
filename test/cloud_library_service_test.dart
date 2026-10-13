import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:petal/data/db/tables.dart';
import 'package:petal/data/services/cloud_library_service.dart';

void main() {
  group('CloudLibraryService', () {
    test('filters Google Drive results to supported audio', () async {
      final service = CloudLibraryService(
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer token');
          return http.Response(
            '{"files":['
            '{"id":"one","name":"Song.mp3","mimeType":"audio/mpeg","size":"42"},'
            '{"id":"two","name":"notes.txt","mimeType":"text/plain"}'
            ']}',
            200,
          );
        }),
      );

      final items = await service.scanGoogleDrive('token');

      expect(items, hasLength(1));
      expect(items.single.provider, TrackSourceType.googleDrive);
      expect(items.single.providerItemId, 'one');
      expect(items.single.title, 'Song');
      expect(items.single.sizeBytes, 42);
    });

    test('recovers artist and title from a tag-less cloud filename', () async {
      final service = CloudLibraryService(
        client: MockClient(
          (_) async => http.Response(
            '{"files":[{"id":"one","name":"Petal Artist - Night Drive.mp3",'
            '"mimeType":"audio/mpeg"}]}',
            200,
          ),
        ),
      );

      final item = (await service.scanGoogleDrive('token')).single;

      expect(item.resolvedArtist, 'Petal Artist');
      expect(item.title, 'Night Drive');
    });

    test('reads OneDrive delta items and ignores folders', () async {
      final service = CloudLibraryService(
        client: MockClient((request) async {
          expect(request.url.host, 'graph.microsoft.com');
          return http.Response(
            '{"value":['
            '{"id":"audio","name":"Cloud.flac","size":99,'
            '"file":{"mimeType":"audio/flac"},'
            '"audio":{"title":"Cloud Song","artist":"Petal Artist",'
            '"album":"Glass","genre":"Ambient","duration":123000},'
            '"thumbnails":[{"medium":{"url":"https://img.example/cover.jpg"}}]},'
            '{"id":"folder","name":"Music","folder":{"childCount":1}}'
            ']}',
            200,
          );
        }),
      );

      final items = await service.scanOneDrive('token');

      expect(items, hasLength(1));
      expect(items.single.provider, TrackSourceType.oneDrive);
      expect(items.single.streamUri, contains('/items/audio/content'));
      expect(items.single.title, 'Cloud Song');
      expect(items.single.resolvedArtist, 'Petal Artist');
      expect(items.single.album, 'Glass');
      expect(items.single.durationMs, 123000);
      expect(items.single.artworkUrl, 'https://img.example/cover.jpg');
    });

    test('scans only a selected OneDrive folder and descendants', () async {
      final paths = <String>[];
      final service = CloudLibraryService(
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers['authorization'], 'Bearer token');
          if (request.url.path.endsWith('/children') && paths.length == 1) {
            return http.Response.bytes(
              utf8.encode(
                '{"value":['
                '{"id":"sub","name":"Sub","folder":{"childCount":1}},'
                '{"id":"a","name":"गाना.flac","file":{"mimeType":"audio/flac"}}'
                ']}',
              ),
              200,
            );
          }
          return http.Response.bytes(
            utf8.encode(
              '{"value":['
              '{"id":"b","name":"বাংলা.mp3","file":{"mimeType":"audio/mpeg"}}'
              ']}',
            ),
            200,
          );
        }),
      );
      final items = await service.scanOneDriveFolder('token', 'Music/Jazz');
      expect(paths.first, contains('/root:/Music/Jazz:/children'));
      expect(paths.last, contains('/items/sub/children'));
      expect(items.map((i) => i.name), ['गाना.flac', 'বাংলা.mp3']);
    });

    test('surfaces expired provider access clearly', () async {
      final service = CloudLibraryService(
        client: MockClient((_) async => http.Response('{}', 401)),
      );

      expect(
        () => service.scanGoogleDrive('expired'),
        throwsA(isA<CloudLibraryException>()),
      );
    });
  });
}
