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
  ItemScrollController _itemScrollController = ItemScrollController();
  ItemPositionsListener _positions = ItemPositionsListener.create();
  int _lastScrolledIndex = -1;
  String? _trackId;

  Future<void> _editLyrics(Track track) async {
    final text = TextEditingController(
      text: track.lyricsLrc ?? track.lyricsPlain ?? '',
    );
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add or edit lyrics'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Paste lyrics in any language. For timed lyrics use LRC lines like [00:12.34]Your line. Plain text works too.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: text,
                  autofocus: true,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Lyrics',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, text.text.trim()),
              child: const Text('Save lyrics'),
            ),
          ],
        ),
      );
      if (value == null || value.isEmpty || !mounted) return;
      await ref.read(playbackControllerProvider.notifier).saveLyrics(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lyrics saved for this song')),
        );
      }
    } finally {
      text.dispose();
    }
  }

  void _maybeAutoScroll(int activeIndex) {
    if (activeIndex < 0 ||
        activeIndex == _lastScrolledIndex ||
        !_itemScrollController.isAttached) {
      return;
    }
    final visible = _positions.itemPositions.value.where(
      (item) => item.index == activeIndex,
    );
    _lastScrolledIndex = activeIndex;
    if (visible.isNotEmpty &&
        visible.first.itemLeadingEdge >= .16 &&
        visible.first.itemTrailingEdge <= .82) {
      return;
    }
    _itemScrollController.scrollTo(
      index: activeIndex,
      alignment: .34,
      duration: const Duration(milliseconds: 380),
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
      return Center(
        child: Text('Play a song to see its lyrics.', style: petal.text.meta),
      );
    }

    if (_trackId != track.id) {
      _trackId = track.id;
      _lastScrolledIndex = -1;
      _itemScrollController = ItemScrollController();
      _positions = ItemPositionsListener.create();
    }

    return SwipeDownToDismiss(
      // Matches the down-arrow button just below: drag-down and tap do the
      // same thing here (back to Now Playing, not all the way to the
      // library — Lyrics is one level "deeper" than Now Playing in this
      // app's flat, non-Navigator section model — see nav_controller.dart).
      onDismiss: () => ref.read(currentSectionProvider.notifier).state =
          AppSection.nowPlaying,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () =>
                      ref.read(currentSectionProvider.notifier).state =
                          AppSection.nowPlaying,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.displayTitle, style: petal.text.sectionTitle),
                      Text(
                        track.displayArtist,
                        style: petal.text.trackSubtitle,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add or edit lyrics',
                  onPressed: () => _editLyrics(track),
                  icon: const Icon(Icons.edit_note_rounded),
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
          Expanded(
            child: _LyricsBody(
              track: track,
              playback: playback,
              controller: controller,
              onAutoScroll: _maybeAutoScroll,
              itemScrollController: _itemScrollController,
              itemPositionsListener: _positions,
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsBody extends StatelessWidget {
  final Track track;
  final PlaybackState playback;
  final PlaybackController controller;
  final void Function(int) onAutoScroll;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;

  const _LyricsBody({
    required this.track,
    required this.playback,
    required this.controller,
    required this.onAutoScroll,
    required this.itemScrollController,
    required this.itemPositionsListener,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final lyrics = playback.lyrics;

    if (lyrics == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!lyrics.found) {
      return Center(
        child: Text(
          'No lyrics found. Use the edit button above to add your own.',
          style: petal.text.meta,
        ),
      );
    }
    if (!lyrics.isSynced) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Expanded(child: Text('Untimed lyrics · highlighting needs timestamps', style: petal.text.meta)),
              IconButton(
                tooltip: 'Search for timed lyrics',
                onPressed: controller.reloadLyrics,
                icon: const Icon(Icons.sync_rounded),
              ),
            ]),
          ),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(
              lyrics.plainText ?? '',
              style: petal.text.lyricLine.copyWith(
                color: petal.colors.ink,
                fontSize: 27,
                height: 1.6,
              ),
            ),
          )),
        ],
      );
    }
    if (lyrics.synced.isEmpty) {
      return Center(
        child: Text('No timed lyric lines.', style: petal.text.meta),
      );
    }

    return StreamBuilder<Duration>(
      stream: controller.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final calibratedPosition =
            position + Duration(milliseconds: playback.lyricsOffsetMs);
        final activeIndex = currentLyricIndex(
          lyrics.synced,
          calibratedPosition,
        );
        final visualActive = activeIndex < 0 ? 0 : activeIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) onAutoScroll(visualActive);
        });

        return ScrollablePositionedList.builder(
          key: ValueKey(track.id),
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
          initialScrollIndex: visualActive,
          initialAlignment: .34,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 140),
          itemCount: lyrics.synced.length,
          itemBuilder: (context, i) {
            final line = lyrics.synced[i];
            final active = i == visualActive;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: InkWell(
                onTap: () => controller.seekToLyricLine(line),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: petal.text.lyricLine.copyWith(
                    color: active ? petal.colors.ink : petal.colors.ink2,
                    fontSize: active ? 34 : 26,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  ),
                  child: Text(line.text),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
