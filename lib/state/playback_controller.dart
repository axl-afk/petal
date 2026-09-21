import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

import '../data/db/app_database.dart';
import '../data/db/daos/track_dao.dart';
import '../data/db/tables.dart';
import '../data/models/lyric_line.dart';
import '../data/models/track_extensions.dart';
import '../data/services/lyrics_service.dart';
import '../data/services/auth/google_auth_service.dart';
import '../data/services/auth/microsoft_auth_service.dart';
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
  final bool shuffleEnabled;
  final LoopMode loopMode;
  final int lyricsOffsetMs;

  const PlaybackState({
    this.current,
    this.queue = const [],
    this.index = -1,
    this.isPlaying = false,
    this.isBuffering = false,
    this.lyrics,
    this.error,
    this.shuffleEnabled = false,
    this.loopMode = LoopMode.off,
    this.lyricsOffsetMs = 0,
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
    bool? shuffleEnabled,
    LoopMode? loopMode,
    int? lyricsOffsetMs,
  }) {
    return PlaybackState(
      current: clearCurrent ? null : (current ?? this.current),
      queue: queue ?? this.queue,
      index: index ?? this.index,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      lyrics: clearLyrics ? null : (lyrics ?? this.lyrics),
      error: clearError ? null : (error ?? this.error),
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      loopMode: loopMode ?? this.loopMode,
      lyricsOffsetMs: lyricsOffsetMs ?? this.lyricsOffsetMs,
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
  late final AudioPlayer player;
  AndroidEqualizer? _equalizer;
  final TrackDao _trackDao;
  final LyricsService _lyricsService;
  final GoogleAuthService _googleAuth;
  final MicrosoftAuthService _microsoftAuth;

  PlaybackController(
    this._trackDao,
    this._lyricsService,
    this._googleAuth,
    this._microsoftAuth,
  ) : super(const PlaybackState()) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _equalizer = AndroidEqualizer();
      player = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer!]),
      );
    } else {
      player = AudioPlayer();
    }
    player.playerStateStream.listen((s) {
      state = state.copyWith(
        isPlaying: s.playing,
        isBuffering:
            s.processingState == ProcessingState.loading ||
            s.processingState == ProcessingState.buffering,
      );
      if (s.processingState == ProcessingState.completed) {
        next();
      }
    });
  }

  Future<void> playQueue(List<Track> queue, int startIndex) async {
    if (queue.isEmpty || startIndex < 0 || startIndex >= queue.length) return;
    state = state.copyWith(
      queue: queue,
      index: startIndex,
      current: queue[startIndex],
      lyricsOffsetMs: queue[startIndex].lyricsOffsetMs,
      clearLyrics: true,
      clearError: true,
    );
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

  Future<void> playAt(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    state = state.copyWith(
      index: index,
      current: state.queue[index],
      lyricsOffsetMs: state.queue[index].lyricsOffsetMs,
      clearLyrics: true,
      clearError: true,
    );
    await _loadCurrentAndPlay();
  }

  void toggleShuffle() {
    state = state.copyWith(shuffleEnabled: !state.shuffleEnabled);
  }

  Future<void> cycleLoopMode() async {
    final next = switch (state.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await player.setLoopMode(next == LoopMode.one ? LoopMode.one : LoopMode.off);
    state = state.copyWith(loopMode: next);
  }

  Future<void> setVolume(double volume) => player.setVolume(volume.clamp(0, 1));

  bool get supportsEqualizer => _equalizer != null;

  Future<AndroidEqualizerParameters?> equalizerParameters() async {
    final equalizer = _equalizer;
    if (equalizer == null) return null;
    await equalizer.setEnabled(true);
    return equalizer.parameters;
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    await _equalizer?.setEnabled(enabled);
  }

  Future<void> applyEqualizerPreset(List<double> normalizedGains) async {
    final parameters = await equalizerParameters();
    if (parameters == null || normalizedGains.isEmpty) return;
    for (var i = 0; i < parameters.bands.length; i++) {
      final normalized = normalizedGains[
        (i * normalizedGains.length ~/ parameters.bands.length)
            .clamp(0, normalizedGains.length - 1)
      ].clamp(-1.0, 1.0).toDouble();
      final gain = normalized >= 0
          ? normalized * parameters.maxDecibels
          : -normalized.abs() * parameters.minDecibels.abs();
      await parameters.bands[i].setGain(gain
          .clamp(parameters.minDecibels, parameters.maxDecibels)
          .toDouble());
    }
  }

  Future<void> next() async {
    if (state.loopMode == LoopMode.one && state.current != null) {
      await seek(Duration.zero);
      await player.play();
      return;
    }
    if (state.shuffleEnabled && state.queue.length > 1) {
      var nextIndex = (DateTime.now().microsecondsSinceEpoch % state.queue.length).toInt();
      if (nextIndex == state.index) nextIndex = (nextIndex + 1) % state.queue.length;
      await playAt(nextIndex);
      return;
    }
    if (!state.hasNext) {
      if (state.loopMode == LoopMode.all && state.queue.isNotEmpty) {
        await playAt(0);
        return;
      }
      await player.pause();
      await player.seek(Duration.zero);
      return;
    }
    await playAt(state.index + 1);
  }

  Future<void> previous() async {
    if (player.position > const Duration(seconds: 3) || !state.hasPrevious) {
      await seek(Duration.zero);
      return;
    }
    await playAt(state.index - 1);
  }

  /// Lyrics-screen click-to-seek: jump to that line's timestamp and resume
  /// playback if it was paused, matching the approved design's "clicking a
  /// lyric plays the song from there" behavior.
  Future<void> seekToLyricLine(LyricLine line) async {
    await seek(line.time - Duration(milliseconds: state.lyricsOffsetMs));
    if (!state.isPlaying) await player.play();
  }

  Future<void> adjustLyricsOffset(int deltaMs) async {
    final track = state.current;
    if (track == null) return;
    final next = (state.lyricsOffsetMs + deltaMs).clamp(-10000, 10000);
    state = state.copyWith(lyricsOffsetMs: next);
    await _trackDao.setLyricsOffset(track.id, next);
  }

  void reflectFavorite(String trackId, bool isFavorite) {
    final current = state.current;
    final updatedQueue = state.queue
        .map((track) => track.id == trackId
            ? track.copyWith(isFavorite: isFavorite)
            : track)
        .toList(growable: false);
    state = state.copyWith(
      current: current?.id == trackId
          ? current!.copyWith(isFavorite: isFavorite)
          : current,
      queue: updatedQueue,
    );
  }

  Future<void> _loadCurrentAndPlay() async {
    final track = state.current;
    if (track == null) return;
    try {
      Uri source;
      Map<String, String>? headers;
      if (track.downloadedPath != null && track.downloadedPath!.isNotEmpty) {
        source = Uri.file(track.downloadedPath!);
      } else if (track.sourceType == TrackSourceType.local) {
        final parsed = Uri.tryParse(track.sourceUri);
        source = parsed != null && parsed.scheme.isNotEmpty
            ? parsed
            : Uri.file(track.sourceUri);
      } else if (track.sourceType == TrackSourceType.googleDrive) {
        final token = await _googleAuth.refreshAccessToken();
        if (token == null)
          throw StateError('Google access expired. Sign in again.');
        source = Uri.parse(track.sourceUri);
        headers = {'Authorization': 'Bearer $token'};
      } else if (track.sourceType == TrackSourceType.oneDrive) {
        final token = await _microsoftAuth.accessToken();
        if (token == null)
          throw StateError('Microsoft access expired. Sign in again.');
        source = Uri.parse(track.sourceUri);
        headers = {'Authorization': 'Bearer $token'};
      } else {
        source = Uri.parse(track.sourceUri);
      }
      await player.setAudioSource(
        AudioSource.uri(
          source,
          headers: headers,
          tag: MediaItem(
            id: track.id,
            title: track.displayTitle,
            artist: track.displayArtist,
            album: track.displayAlbum.isEmpty ? null : track.displayAlbum,
            duration: track.duration.inMilliseconds > 0
                ? track.duration
                : null,
            artUri: _artworkUri(track.artworkUrl),
            playable: true,
          ),
        ),
      );
      await player.play();
      state = state.copyWith(clearError: true);
    } catch (e) {
      state = state.copyWith(
        isPlaying: false,
        error: 'Could not play "${track.displayTitle}": $e',
      );
    }
    unawaited(_loadLyricsFor(track));
  }

  Uri? _artworkUri(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.scheme.isNotEmpty) return parsed;
    return Uri.file(raw);
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
      title: track.displayTitle,
      artist: track.displayArtist,
      album: track.displayAlbum,
      duration: track.duration,
    );

    if (state.current?.id != track.id)
      return; // user moved on before this resolved
    state = state.copyWith(lyrics: result);

    if (result.isSynced) {
      await _trackDao.cacheLyrics(track.id, lrc: toLrcText(result.synced));
    } else if (result.plainText != null) {
      await _trackDao.cacheLyrics(track.id, plain: result.plainText);
    }
  }

  /// Re-runs the embedded/online lyrics pipeline for the current track. This
  /// is intentionally public so a failed network lookup is recoverable from
  /// the player without skipping away and coming back.
  Future<void> reloadLyrics() async {
    final track = state.current;
    if (track == null) return;
    state = state.copyWith(clearLyrics: true);
    await _loadLyricsFor(track);
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}

void unawaited(Future<void> future) {}

final playbackControllerProvider =
    StateNotifierProvider<PlaybackController, PlaybackState>((ref) {
      // Riverpod calls PlaybackController.dispose() (which disposes the
      // AudioPlayer) automatically when this provider is torn down — no need to
      // register a second ref.onDispose here.
      return PlaybackController(
        ref.watch(trackDaoProvider),
        ref.watch(lyricsServiceProvider),
        ref.watch(googleAuthServiceProvider),
        ref.watch(microsoftAuthServiceProvider),
      );
    });
