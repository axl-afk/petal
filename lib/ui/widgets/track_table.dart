import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/models/track_extensions.dart';
import '../../state/library_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/playback_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/duration_format.dart';

/// The track listing used by every "songs" view (full library, an artist,
/// a genre, a playlist, favorites, or search results) — same table, just a
/// different underlying stream, matching how the approved design reused one
/// track-table component everywhere rather than bespoke layouts per section.
///
/// This is a *sliver* — meant to sit inside a CustomScrollView alongside the
/// hero banner (see library_screen.dart) — specifically so a library of
/// thousands of tracks only ever builds the rows currently on/near screen
/// (SliverChildBuilderDelegate), rather than eagerly building every row up
/// front the way a plain Column inside a ScrollView would.
class TrackTable extends ConsumerWidget {
  final List<Track> tracks;
  const TrackTable({super.key, required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petal = context.petal;

    if (tracks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('Nothing here yet.', style: petal.text.meta)),
        ),
      );
    }

    // Only current-track identity/playing state is watched here — position
    // ticks are deliberately kept out of PlaybackState (see
    // playback_controller.dart), so this sliver doesn't rebuild dozens of
    // times a second while something plays.
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final track = tracks[i];
          return _TrackRow(
            key: ValueKey(track.id),
            index: i + 1,
            track: track,
            isCurrent: playback.current?.id == track.id,
            isPlaying: playback.isPlaying && playback.current?.id == track.id,
            onPlay: () => controller.playSingle(track, context: tracks),
            onToggleFavorite: () => ref.read(libraryControllerProvider.notifier).toggleFavorite(track),
            onOpenNowPlaying: () => ref.read(currentSectionProvider.notifier).state = AppSection.nowPlaying,
          );
        },
        childCount: tracks.length,
      ),
    );
  }
}

class _TrackRow extends StatefulWidget {
  final int index;
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenNowPlaying;

  const _TrackRow({
    super.key,
    required this.index,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onOpenNowPlaying,
  });

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final track = widget.track;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: widget.isCurrent ? petal.colors.surface2 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.isCurrent ? widget.onOpenNowPlaying : widget.onPlay,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: (_hover || widget.isCurrent)
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          icon: Icon(widget.isPlaying ? Icons.pause : Icons.play_arrow, color: petal.colors.ink),
                          onPressed: widget.onPlay,
                        )
                      : Text('${widget.index}', style: petal.text.meta, textAlign: TextAlign.center),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.isCurrent ? petal.text.trackTitleCurrent : petal.text.trackTitle,
                      ),
                      Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: petal.text.trackSubtitle),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(track.album, maxLines: 1, overflow: TextOverflow.ellipsis, style: petal.text.meta),
                ),
                SizedBox(
                  width: 70,
                  child: Text(formatDuration(track.duration), style: petal.text.meta, textAlign: TextAlign.right),
                ),
                SizedBox(
                  width: 34,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(track.isFavorite ? Icons.favorite : Icons.favorite_border),
                    color: track.isFavorite ? petal.colors.ink : petal.colors.ink3,
                    onPressed: widget.onToggleFavorite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
