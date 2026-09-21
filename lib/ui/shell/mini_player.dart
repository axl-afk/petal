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
                      Text(track.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: petal.text.miniTitle),
                      Text(track.displayArtist,
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _MiniTimeline(
                        fallbackDuration: track.duration,
                        controller: controller,
                        compact: compact,
                      ),
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 180,
                    child: _MiniVolume(controller: controller),
                  ),
                ],
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
  final Duration fallbackDuration;
  final PlaybackController controller;
  final bool compact;

  const _MiniTimeline({
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
          final progress = (position.inMilliseconds / totalMs)
              .clamp(0.0, 1.0)
              .toDouble();
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: compact ? 3 : 4,
                  activeTrackColor: petal.colors.accent,
                  inactiveTrackColor: petal.colors.ink3.withOpacity(.28),
                  thumbColor: petal.colors.accent,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
                ),
                child: Slider(
                  value: progress,
                  onChanged: (fraction) => controller.seek(
                    Duration(milliseconds: (totalMs * fraction).round()),
                  ),
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

class _MiniVolume extends StatelessWidget {
  final PlaybackController controller;
  const _MiniVolume({required this.controller});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return StreamBuilder<double>(
      stream: controller.player.volumeStream,
      initialData: controller.player.volume,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? 1;
        return Row(
          children: [
            IconButton(
              tooltip: volume == 0 ? 'Unmute' : 'Mute',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 38),
              onPressed: () => controller.setVolume(volume == 0 ? 1 : 0),
              icon: Icon(
                volume == 0
                    ? Icons.volume_off_rounded
                    : volume < .5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
                size: 20,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: petal.colors.accent,
                  inactiveTrackColor: petal.colors.ink3.withOpacity(.28),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
                ),
                child: Slider(value: volume, onChanged: controller.setVolume),
              ),
            ),
          ],
        );
      },
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
