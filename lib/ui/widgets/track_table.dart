import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/tables.dart';
import '../../data/models/track_extensions.dart';
import '../../state/library_controller.dart';
import '../../state/download_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/playback_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/duration_format.dart';
import 'track_art.dart';

/// The track listing used by every "songs" view (full library, an artist,
/// a genre, a playlist, favorites, or search results) — same table, just a
/// different underlying stream, matching how the approved design reused one
/// track-table component everywhere rather than bespoke layouts per section.
///
/// This is a *sliver* — meant to sit inside a CustomScrollView — so a library of
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
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.library_music_outlined,
                  size: 42, color: petal.colors.ink3),
              const SizedBox(height: 12),
              Text('Nothing here yet.', style: petal.text.sectionTitle),
              const SizedBox(height: 4),
              Text('Add a source or scan this device for music.',
                  style: petal.text.meta),
            ],
          ),
        ),
      );
    }

    // Only current-track identity/playing state is watched here — position
    // ticks are deliberately kept out of PlaybackState (see
    // playback_controller.dart), so this sliver doesn't rebuild dozens of
    // times a second while something plays.
    final playback = ref.watch(playbackControllerProvider);
    final downloads = ref.watch(downloadControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    // One flat sliver is deliberately used here. The previous
    // SliverMainAxisGroup -> SliverList -> SliverFillRemaining nesting could
    // produce invalid remaining-paint geometry while a desktop window entered
    // fullscreen, and release builds rendered the whole center pane blank.
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, rawIndex) {
          if (rawIndex == 0) {
            return _TrackHeader(
              showDetails: MediaQuery.sizeOf(context).width >= 720,
            );
          }
          final i = rawIndex - 1;
          final track = tracks[i];
          return _TrackRow(
            key: ValueKey(track.id),
            index: i + 1,
            track: track,
            isCurrent: playback.current?.id == track.id,
            isPlaying:
                playback.isPlaying && playback.current?.id == track.id,
            onPlay: () => controller.playSingle(track, context: tracks),
            onToggleFavorite: () => ref
                .read(libraryControllerProvider.notifier)
                .toggleFavorite(track),
            onOpenNowPlaying: () =>
                ref.read(currentSectionProvider.notifier).state =
                    AppSection.nowPlaying,
            downloadState: downloads[track.id],
            onDownload: () => ref
                .read(downloadControllerProvider.notifier)
                .download(track),
            onRemoveDownload: () => ref
                .read(downloadControllerProvider.notifier)
                .remove(track),
          );
        },
        childCount: tracks.length + 1,
      ),
    );
  }
}

class _TrackHeader extends StatelessWidget {
  final bool showDetails;
  const _TrackHeader({required this.showDetails});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: petal.colors.surface.withOpacity(.66),
        border: Border.symmetric(
          horizontal: BorderSide(color: petal.colors.hairline),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('#', style: petal.text.meta)),
          const SizedBox(width: 54),
          Expanded(flex: 3, child: Text('Title', style: petal.text.meta)),
          if (showDetails) ...[
            Expanded(flex: 2, child: Text('Album', style: petal.text.meta)),
            SizedBox(
              width: 70,
              child: Icon(Icons.schedule_rounded,
                  size: 14, color: petal.colors.ink3),
            ),
          ],
          const SizedBox(width: 34),
          const SizedBox(width: 36),
        ],
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
  final TrackDownloadState? downloadState;
  final VoidCallback onDownload;
  final VoidCallback onRemoveDownload;

  const _TrackRow({
    super.key,
    required this.index,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onOpenNowPlaying,
    required this.downloadState,
    required this.onDownload,
    required this.onRemoveDownload,
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
    final compact = MediaQuery.sizeOf(context).width < 720;

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
                          icon: Icon(
                            widget.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: petal.colors.ink,
                          ),
                          onPressed: widget.onPlay,
                        )
                      : Text(
                          '${widget.index}',
                          style: petal.text.meta,
                          textAlign: TextAlign.center,
                        ),
                ),
                const SizedBox(width: 8),
                // The actual "playlist view music icon doesn't show up" fix
                // — every row used to skip straight from the index/play
                // button to text, with no artwork/placeholder icon at all,
                // unlike MiniPlayer and NowPlayingScreen (both already used
                // TrackArt). Falls back to the same music-note placeholder
                // those do when a track has no artwork.
                TrackArt(
                  track: track,
                  size: 36,
                  iconSize: 16,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.isCurrent
                            ? petal.text.trackTitleCurrent
                            : petal.text.trackTitle,
                      ),
                      Text(
                        track.displayArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: petal.text.trackSubtitle,
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      track.displayAlbum,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: petal.text.meta,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      formatDuration(track.duration),
                      style: petal.text.meta,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
                SizedBox(
                  width: 34,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(
                      track.isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                    color: track.isFavorite
                        ? petal.colors.ink
                        : petal.colors.ink3,
                    onPressed: widget.onToggleFavorite,
                  ),
                ),
                if (track.sourceType != TrackSourceType.local)
                  SizedBox(
                    width: 36,
                    child: _DownloadButton(
                      track: track,
                      state: widget.downloadState,
                      onDownload: widget.onDownload,
                      onRemove: widget.onRemoveDownload,
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

class _DownloadButton extends StatelessWidget {
  final Track track;
  final TrackDownloadState? state;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  const _DownloadButton({
    required this.track,
    required this.state,
    required this.onDownload,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (state?.status == DownloadStatus.downloading) {
      return Padding(
        padding: const EdgeInsets.all(9),
        child: CircularProgressIndicator(
          value: state!.progress,
          strokeWidth: 2,
        ),
      );
    }
    if (state?.status == DownloadStatus.failed) {
      return IconButton(
        tooltip: state!.error ?? 'Download failed — tap to retry',
        iconSize: 18,
        onPressed: onDownload,
        icon: const Icon(Icons.cloud_off_outlined, color: Colors.redAccent),
      );
    }
    if (track.downloadedPath != null) {
      return IconButton(
        tooltip: 'Available offline — tap to remove download',
        iconSize: 18,
        onPressed: onRemove,
        icon: const Icon(Icons.offline_pin_outlined),
      );
    }
    return IconButton(
      tooltip: 'Download for offline playback',
      iconSize: 18,
      onPressed: onDownload,
      icon: const Icon(Icons.download_for_offline_outlined),
    );
  }
}
