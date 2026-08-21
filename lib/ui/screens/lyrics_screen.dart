import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../state/nav_controller.dart';
import '../../state/playback_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/lyric_sync.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  const LyricsScreen({super.key});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  final _scrollController = ScrollController();
  int _lastScrolledIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeAutoScroll(int activeIndex, int totalLines) {
    if (activeIndex < 0 || activeIndex == _lastScrolledIndex || !_scrollController.hasClients) return;
    _lastScrolledIndex = activeIndex;
    const lineHeight = 64.0;
    final target = (activeIndex * lineHeight - 160).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
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

    return Column(
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
                    Text(track.title, style: petal.text.sectionTitle),
                    Text(track.artist, style: petal.text.trackSubtitle),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _LyricsBody(track: track, playback: playback, controller: controller, onAutoScroll: _maybeAutoScroll, scrollController: _scrollController)),
      ],
    );
  }
}

class _LyricsBody extends StatelessWidget {
  final Track track;
  final PlaybackState playback;
  final PlaybackController controller;
  final void Function(int, int) onAutoScroll;
  final ScrollController scrollController;

  const _LyricsBody({
    required this.track,
    required this.playback,
    required this.controller,
    required this.onAutoScroll,
    required this.scrollController,
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
        final activeIndex = currentLyricIndex(lyrics.synced, position);
        WidgetsBinding.instance.addPostFrameCallback((_) => onAutoScroll(activeIndex, lyrics.synced.length));

        return ListView.builder(
          controller: scrollController,
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
