import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../data/db/app_database.dart';
import '../../data/models/track_extensions.dart';
import '../../state/nav_controller.dart';
import '../../state/playback_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/lyric_sync.dart';
import '../widgets/swipe_down_to_dismiss.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  const LyricsScreen({super.key});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  final _itemScrollController = ItemScrollController();
  int _lastScrolledIndex = -1;

  void _maybeAutoScroll(int activeIndex, int totalLines) {
    if (activeIndex < 0 ||
        activeIndex == _lastScrolledIndex ||
        !_itemScrollController.isAttached) {
      return;
    }
    _lastScrolledIndex = activeIndex;
    _itemScrollController.scrollTo(
      index: activeIndex,
      alignment: .34,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final track = playback.current;

    if (track == null) {
      return Center(child: Text('Play a song to see its lyrics.', style: petal.text.meta));
    }

    return SwipeDownToDismiss(
      // Matches the down-arrow button just below: drag-down and tap do the
      // same thing here (back to Now Playing, not all the way to the
      // library — Lyrics is one level "deeper" than Now Playing in this
      // app's flat, non-Navigator section model — see nav_controller.dart).
      onDismiss: () => ref.read(currentSectionProvider.notifier).state = AppSection.nowPlaying,
      child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: () => ref.read(currentSectionProvider.notifier).state = AppSection.nowPlaying,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.displayTitle, style: petal.text.sectionTitle),
                    Text(track.displayArtist, style: petal.text.trackSubtitle),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Lyrics earlier by 0.25 seconds',
                onPressed: () => controller.adjustLyricsOffset(-250),
                icon: const Icon(Icons.remove_rounded),
              ),
              Text(
                '${playback.lyricsOffsetMs >= 0 ? '+' : ''}${(playback.lyricsOffsetMs / 1000).toStringAsFixed(2)}s',
                style: petal.text.meta,
              ),
              IconButton(
                tooltip: 'Lyrics later by 0.25 seconds',
                onPressed: () => controller.adjustLyricsOffset(250),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Expanded(child: _LyricsBody(track: track, playback: playback, controller: controller, onAutoScroll: _maybeAutoScroll, itemScrollController: _itemScrollController)),
      ],
      ),
    );
  }
}

class _LyricsBody extends StatelessWidget {
  final Track track;
  final PlaybackState playback;
  final PlaybackController controller;
  final void Function(int, int) onAutoScroll;
  final ItemScrollController itemScrollController;

  const _LyricsBody({
    required this.track,
    required this.playback,
    required this.controller,
    required this.onAutoScroll,
    required this.itemScrollController,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final lyrics = playback.lyrics;

    if (lyrics == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!lyrics.found) {
      return Center(child: Text('No lyrics found for this song.', style: petal.text.meta));
    }
    if (!lyrics.isSynced) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(lyrics.plainText ?? '', style: petal.text.lyricLine.copyWith(color: petal.colors.ink)),
      );
    }

    return StreamBuilder<Duration>(
      stream: controller.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final calibratedPosition = position +
            Duration(milliseconds: playback.lyricsOffsetMs);
        final activeIndex = currentLyricIndex(lyrics.synced, calibratedPosition);
        WidgetsBinding.instance.addPostFrameCallback((_) => onAutoScroll(activeIndex, lyrics.synced.length));

        return ScrollablePositionedList.builder(
          itemScrollController: itemScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 140),
          itemCount: lyrics.synced.length,
          itemBuilder: (context, i) {
            final line = lyrics.synced[i];
            final active = i == activeIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: InkWell(
                onTap: () => controller.seekToLyricLine(line),
                child: Text(line.text, style: active ? petal.text.lyricLineActive : petal.text.lyricLine),
              ),
            );
          },
        );
      },
    );
  }
}
