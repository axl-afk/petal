import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/db/app_database.dart';
import '../data/db/daos/track_dao.dart';
import '../data/db/tables.dart';
import '../data/models/lyric_line.dart';
import '../data/models/track_extensions.dart';
import '../data/services/lyrics_service.dart';
import '../utils/lyric_sync.dart';
import 'providers.dart';

class PlaybackState {
  final Track? current;
  final List<Track> queue;
  final int index;
  final bool isPlaying;
  final bool isBuffering;
  final LyricsResult? lyrics;
  final String? error;

  const PlaybackState({
    this.current,
    this.queue = const [],
    this.index = -1,
    this.isPlaying = false,
    this.isBuffering = false,
    this.lyrics,
    this.error,
  });

  bool get hasNext => index >= 0 && index < queue.length - 1;
  bool get hasPrevious => index > 0;

  PlaybackState copyWith({
    Track? current,
    bool clearCurrent = false,
    List<Track>? queue,
    int? index,
    bool? isPlaying,
    bool? isBuffering,
    LyricsResult? lyrics,
    bool clearLyrics = false,
    String? error,
    bool clearError = false,
  }) {
    return PlaybackState(
      current: clearCurrent ? null : (current ?? this.current),
      queue: queue ?? this.queue,
      index: index ?? this.index,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      lyrics: clearLyrics ? null : (lyrics ?? this.lyrics),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the single `just_audio` player instance and everything derived from
/// it: the play queue, current-track lyrics (fetched from lrclib.net and
/// cached back onto the track row), and transport controls. Position and
/// duration are deliberately *not* mirrored into [PlaybackState] — they tick
/// many times a second, so widgets that need them (the waveform seek bar,
/// the time labels) should watch [player].positionStream /
/// [player].durationStream directly via a StreamBuilder, keeping this
/// notifier's rebuilds cheap.
class PlaybackController extends StateNotifier<PlaybackState> {
  final AudioPlayer player = AudioPlayer();
  final TrackDao _trackDao;
  final LyricsService _lyricsService;

  PlaybackController(this._trackDao, this._lyricsService) : super(const PlaybackState()) {
    player.playerStateStream.listen((s) {
      state = state.copyWith(
        isPlaying: s.playing,
        isBuffering: s.processingState == ProcessingState.loading ||
            s.processingState == ProcessingState.buffering,
      );
      if (s.processingState == ProcessingState.completed) {
        next();
      }
    });
  }

  Future<void> playQueue(List<Track> queue, int startIndex) async {
    if (queue.isEmpty || startIndex < 0 || startIndex >= queue.length) return;
    state = state.copyWith(queue: queue, index: startIndex, current: queue[startIndex], clearLyrics: true, clearError: true);
    await _loadCurrentAndPlay();
  }

  Future<void> playSingle(Track track, {List<Track>? context}) async {
    final list = context ?? [track];
    final idx = list.indexWhere((t) => t.id == track.id);
    await playQueue(list, idx < 0 ? 0 : idx);
  }

  Future<void> togglePlayPause() async {
    if (state.current == null) return;
    if (state.isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> seek(Duration position) => player.seek(position);

  Future<void> next() async {
    if (!state.hasNext) {
      await player.pause();
      await player.seek(Duration.zero);
      return;
    }
    final nextIndex = state.index + 1;
    state = state.copyWith(index: nextIndex, current: state.queue[nextIndex], clearLyrics: true);
    await _loadCurrentAndPlay();
  }

  Future<void> previous() async {
    if (player.position > const Duration(seconds: 3) || !state.hasPrevious) {
      await seek(Duration.zero);
      return;
    }
    final prevIndex = state.index - 1;
    state = state.copyWith(index: prevIndex, current: state.queue[prevIndex], clearLyrics: true);
    await _loadCurrentAndPlay();
  }

  /// Lyrics-screen click-to-seek: jump to that line's timestamp and resume
  /// playback if it was paused, matching the approved design's "clicking a
  /// lyric plays the song from there" behavior.
  Future<void> seekToLyricLine(LyricLine line) async {
    await seek(line.time);
    if (!state.isPlaying) await player.play();
  }

  Future<void> _loadCurrentAndPlay() async {
    final track = state.current;
    if (track == null) return;
    try {
      if (track.sourceType == TrackSourceType.local) {
        await player.setFilePath(track.sourceUri);
      } else {
        await player.setUrl(track.sourceUri);
      }
      await player.play();
      state = state.copyWith(clearError: true);
    } catch (e) {
      state = state.copyWith(isPlaying: false, error: 'Could not play "${track.title}": $e');
    }
    unawaited(_loadLyricsFor(track));
  }

  Future<void> _loadLyricsFor(Track track) async {
    if (track.lyricsLrc != null && track.lyricsLrc!.trim().isNotEmpty) {
      final lines = LyricsService.parseLrc(track.lyricsLrc!);
      if (state.current?.id == track.id) {
        state = state.copyWith(lyrics: LyricsResult.synced(lines));
      }
      return;
    }
    if (track.lyricsPlain != null && track.lyricsPlain!.trim().isNotEmpty) {
      if (state.current?.id == track.id) {
        state = state.copyWith(lyrics: LyricsResult.plain(track.lyricsPlain));
      }
      return;
    }

    final result = await _lyricsService.fetch(
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
    );

    if (state.current?.id != track.id) return; // user moved on before this resolved
    state = state.copyWith(lyrics: result);

    if (result.isSynced) {
      await _trackDao.cacheLyrics(track.id, lrc: toLrcText(result.synced));
    } else if (result.plainText != null) {
      await _trackDao.cacheLyrics(track.id, plain: result.plainText);
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}

void unawaited(Future<void> future) {}

final playbackControllerProvider = StateNotifierProvider<PlaybackController, PlaybackState>((ref) {
  // Riverpod calls PlaybackController.dispose() (which disposes the
  // AudioPlayer) automatically when this provider is torn down — no need to
  // register a second ref.onDispose here.
  return PlaybackController(ref.watch(trackDaoProvider), ref.watch(lyricsServiceProvider));
});
