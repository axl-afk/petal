import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lyric_line.dart';

/// Fetches real time-synced lyrics from lrclib.net — a free, no-API-key
/// public lyrics database that returns LRC-format synced lyrics, which is
/// exactly the karaoke-style timing data the click-to-seek Lyrics screen
/// needs.
class LyricsService {
  static const _base = 'https://lrclib.net/api';

  final http.Client _client;
  LyricsService({http.Client? client}) : _client = client ?? http.Client();

  Future<LyricsResult> fetch({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    // 1. Try the exact-match endpoint first — fastest and most accurate when
    // it hits.
    final exact = await _tryGetExact(title: title, artist: artist, album: album, duration: duration);
    if (exact != null) return exact;

    // 2. Fall back to search and take the closest-duration result.
    return _trySearch(title: title, artist: artist, duration: duration);
  }

  Future<LyricsResult?> _tryGetExact({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    final params = <String, String>{
      'track_name': title,
      'artist_name': artist,
      if (album != null && album.isNotEmpty) 'album_name': album,
      if (duration != null) 'duration': duration.inSeconds.toString(),
    };
    final uri = Uri.parse('$_base/get').replace(queryParameters: params);

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return _resultFromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<LyricsResult> _trySearch({
    required String title,
    required String artist,
    Duration? duration,
  }) async {
    final uri = Uri.parse('$_base/search').replace(queryParameters: {
      'track_name': title,
      'artist_name': artist,
    });

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const LyricsResult.notFound();
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return const LyricsResult.notFound();

      Map<String, dynamic> best = list.first as Map<String, dynamic>;
      if (duration != null) {
        var bestDiff = 1 << 30;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final d = (map['duration'] as num?)?.toInt();
          if (d == null) continue;
          final diff = (d - duration.inSeconds).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            best = map;
          }
        }
      }
      return _resultFromJson(best);
    } catch (_) {
      return const LyricsResult.notFound();
    }
  }

  LyricsResult _resultFromJson(Map<String, dynamic> json) {
    final synced = json['syncedLyrics'] as String?;
    final plain = json['plainLyrics'] as String?;

    if (synced != null && synced.trim().isNotEmpty) {
      final lines = parseLrc(synced);
      if (lines.isNotEmpty) return LyricsResult.synced(lines);
    }
    if (plain != null && plain.trim().isNotEmpty) {
      return LyricsResult.plain(plain);
    }
    return const LyricsResult.notFound();
  }

  /// Parses standard LRC `[mm:ss.xx]lyric text` lines. Lines without a
  /// timestamp, or blank lines, are skipped. A line can carry more than one
  /// timestamp tag (rare but valid LRC) — each becomes its own [LyricLine].
  static List<LyricLine> parseLrc(String lrc) {
    final tagPattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
    final out = <LyricLine>[];

    for (final rawLine in lrc.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty) continue;

      final matches = tagPattern.allMatches(line).toList();
      if (matches.isEmpty) continue;

      final text = line.replaceAll(tagPattern, '').trim();
      if (text.isEmpty) continue;

      for (final m in matches) {
        final minutes = int.parse(m.group(1)!);
        final seconds = int.parse(m.group(2)!);
        final fracStr = m.group(3);
        final millis = fracStr == null
            ? 0
            : int.parse(fracStr.padRight(3, '0').substring(0, 3));
        out.add(LyricLine(
          time: Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
          text: text,
        ));
      }
    }

    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }
}
