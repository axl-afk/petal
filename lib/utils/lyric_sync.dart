import '../data/models/lyric_line.dart';

/// Index of the lyric line that should be highlighted for the given
/// playback [position] — the last line whose timestamp has passed. Returns
/// -1 if playback hasn't reached the first line yet.
int currentLyricIndex(List<LyricLine> lines, Duration position) {
  var result = -1;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].time <= position) {
      result = i;
    } else {
      break;
    }
  }
  return result;
}

/// Re-serializes parsed lyric lines back to LRC text, for caching a fetched
/// result on the track row so it isn't re-fetched from lrclib.net every play.
String toLrcText(List<LyricLine> lines) {
  final buffer = StringBuffer();
  for (final line in lines) {
    final totalMs = line.time.inMilliseconds;
    final minutes = (totalMs ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((totalMs ~/ 1000) % 60).toString().padLeft(2, '0');
    final centis = ((totalMs % 1000) ~/ 10).toString().padLeft(2, '0');
    buffer.writeln('[$minutes:$seconds.$centis]${line.text}');
  }
  return buffer.toString();
}
