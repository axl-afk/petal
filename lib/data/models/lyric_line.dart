/// A single time-synced lyric line, as parsed from an LRC file.
class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({required this.time, required this.text});

  @override
  String toString() => '[$time] $text';
}

/// Result of a lyrics lookup: either a synced (line-by-line timed) lyric set,
/// a plain-text fallback (no timing data available), or nothing found.
class LyricsResult {
  final List<LyricLine> synced;
  final String? plainText;
  final bool found;

  const LyricsResult.synced(this.synced)
      : plainText = null,
        found = true;

  const LyricsResult.plain(this.plainText)
      : synced = const [],
        found = true;

  const LyricsResult.notFound()
      : synced = const [],
        plainText = null,
        found = false;

  bool get isSynced => synced.isNotEmpty;
}
