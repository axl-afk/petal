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

    test('reads OneDrive delta items and ignores folders', () async {
      final service = CloudLibraryService(
        client: MockClient((request) async {
          expect(request.url.host, 'graph.microsoft.com');
          return http.Response(
            '{"value":['
            '{"id":"audio","name":"Cloud.flac","size":99,'
            '"file":{"mimeType":"audio/flac"}},'
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
