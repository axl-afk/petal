import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/track_extensions.dart';
import '../../data/services/window/window_service.dart';
import '../../state/library_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/playback_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/duration_format.dart';
import '../../utils/ui_scale.dart';
import '../widgets/track_art.dart';
import '../widgets/waveform_seekbar.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petal = context.petal;
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final track = playback.current;
    if (track == null) return const SizedBox.shrink();

    final scale = UiScale.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final veryNarrow = width < 430;

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 0 : 22, 0, compact ? 0 : 22, 10),
      child: Material(
        color: petal.colors.surface.withOpacity(.94),
        elevation: compact ? 0 : 8,
        shadowColor: Colors.black.withOpacity(.22),
        borderRadius: BorderRadius.circular(compact ? 0 : 24),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(currentSectionProvider.notifier).state =
              AppSection.nowPlaying,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -250) {
              ref.read(currentSectionProvider.notifier).state =
                  AppSection.nowPlaying;
            }
          },
          child: SizedBox(
            height: (compact ? 84 : 86) * scale,
            child: Row(
              children: [
                const SizedBox(width: 12),
                TrackArt(track: track, size: 50 * scale, iconSize: 19),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: veryNarrow ? 84 : 120,
                    maxWidth: compact ? 180 : 230,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: petal.text.miniTitle),
                      Text(track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: petal.text.miniArtist),
                    ],
                  ),
                ),
                if (!compact) ...[
                  IconButton(
                    tooltip: track.isFavorite
                        ? 'Remove from favorites'
                        : 'Add to favorites',
                    icon: Icon(track.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border),
                    color: track.isFavorite
                        ? petal.colors.accent
                        : petal.colors.ink2,
                    onPressed: () => ref
                        .read(libraryControllerProvider.notifier)
                        .toggleFavorite(track),
                  ),
                  IconButton(
                    tooltip: 'Previous',
                    icon: const Icon(Icons.skip_previous_rounded, size: 24),
                    onPressed: controller.previous,
                  ),
                ],
                _MiniPlayPause(
                  playing: playback.isPlaying,
                  buffering: playback.isBuffering,
                  onTap: controller.togglePlayPause,
                ),
                IconButton(
                  tooltip: 'Next',
                  icon: const Icon(Icons.skip_next_rounded, size: 24),
                  onPressed: controller.next,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _MiniTimeline(
                    trackId: track.id,
                    fallbackDuration: track.duration,
                    controller: controller,
                    compact: compact,
                  ),
                ),
                if (!compact)
                  IconButton(
                    tooltip: 'Full screen',
                    onPressed: WindowService.toggleFullscreen,
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTimeline extends StatelessWidget {
  final String trackId;
  final Duration fallbackDuration;
  final PlaybackController controller;
  final bool compact;

  const _MiniTimeline({
    required this.trackId,
    required this.fallbackDuration,
    required this.controller,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return StreamBuilder<Duration?>(
      stream: controller.player.durationStream,
      builder: (context, durationSnapshot) => StreamBuilder<Duration>(
        stream: controller.player.positionStream,
        builder: (context, positionSnapshot) {
          final position = positionSnapshot.data ?? Duration.zero;
          final duration = durationSnapshot.data ?? fallbackDuration;
          final totalMs = math.max(1, duration.inMilliseconds);
          final progress =
              (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WaveformSeekBar(
                seed: trackId,
                progress: progress,
                height: compact ? 26 : 30,
                filledColor: petal.colors.accent,
                unfilledColor: petal.colors.ink3.withOpacity(.35),
                onSeekFraction: (fraction) => controller.seek(
                  Duration(milliseconds: (totalMs * fraction).round()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(position), style: petal.text.meta),
                  Text(formatDuration(duration), style: petal.text.meta),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniPlayPause extends StatelessWidget {
  final bool playing;
  final bool buffering;
  final VoidCallback onTap;
  const _MiniPlayPause({
    required this.playing,
    required this.buffering,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return IconButton(
      tooltip: playing ? 'Pause' : 'Play',
      icon: buffering
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: petal.colors.ink,
              ),
            )
          : Icon(
              playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              size: 34,
            ),
      color: petal.colors.ink,
      onPressed: buffering ? null : onTap,
    );
  }
}
