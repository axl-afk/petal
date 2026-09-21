import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:petal/data/services/lyrics_service.dart';

void main() {
  test('normalizes filename tags and scores synced lyrics above loose results', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      expect(request.headers['user-agent'], contains('Petal/'));
      if (request.url.path.endsWith('/get')) {
        return http.Response('{}', 404);
      }
      return http.Response(
        jsonEncode([
          {
            'trackName': 'Wishes',
            'artistName': 'Another Artist',
            'duration': 218,
            'plainLyrics': 'Wrong result',
          },
          {
            'trackName': 'Wishes',
            'artistName': 'Hasan Raheem',
            'duration': 218,
            'syncedLyrics': '[00:01.00]First line\n[00:04.20]Second line',
          },
        ]),
        200,
      );
    });

    final result = await LyricsService(client: client).fetch(
      title: 'Wishes (Official Audio).mp3',
      artist: 'Hasan Raheem (feat. guest)',
      duration: const Duration(seconds: 218),
    );

    expect(result.isSynced, isTrue);
    expect(result.synced.map((line) => line.text), ['First line', 'Second line']);
    final search = requests.last;
    expect(search.queryParameters['track_name'], 'Wishes');
    expect(search.queryParameters['artist_name'], 'Hasan Raheem');
  });

  test('parses multiple timestamps and keeps lyric time order', () {
    final lines = LyricsService.parseLrc(
      '[00:10.00][00:20.50]Chorus\n[00:03.25]Verse',
    );

    expect(lines.map((line) => line.text), ['Verse', 'Chorus', 'Chorus']);
    expect(lines.first.time, const Duration(seconds: 3, milliseconds: 250));
    expect(lines.last.time, const Duration(seconds: 20, milliseconds: 500));
  });
}
