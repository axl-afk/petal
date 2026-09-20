import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/track_extensions.dart';
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
    final narrow = width < 430;

    return GestureDetector(
      onTap: () => ref.read(currentSectionProvider.notifier).state = AppSection.nowPlaying,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -250) {
          ref.read(currentSectionProvider.notifier).state = AppSection.nowPlaying;
        }
      },
      child: Container(
        height: 72 * scale,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: petal.colors.surface.withOpacity(0.9),
          border: Border(top: BorderSide(color: petal.colors.hairline)),
        ),
        child: Row(
          children: [
            TrackArt(track: track, size: 44 * scale, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: petal.text.miniTitle),
                  Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: petal.text.miniArtist),
                ],
              ),
            ),
            if (!narrow)
              IconButton(
                icon: Icon(track.isFavorite ? Icons.favorite : Icons.favorite_border, size: 18),
                color: track.isFavorite ? petal.colors.ink : petal.colors.ink2,
                onPressed: () => ref.read(libraryControllerProvider.notifier).toggleFavorite(track),
              ),
            if (!compact)
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 22),
                color: petal.colors.ink,
                onPressed: controller.previous,
              ),
            _MiniPlayPause(playing: playback.isPlaying, buffering: playback.isBuffering, onTap: controller.togglePlayPause),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 22),
              color: petal.colors.ink,
              onPressed: controller.next,
            ),
            if (!compact)
              SizedBox(
              width: 120,
              child: StreamBuilder<Duration>(
                stream: controller.player.positionStream,
                builder: (context, snapshot) {
                  final pos = snapshot.data ?? Duration.zero;
                  final dur = track.duration.inMilliseconds > 0 ? track.duration : (controller.player.duration ?? Duration.zero);
                  final progress = dur.inMilliseconds == 0 ? 0.0 : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: petal.colors.surface2,
                          valueColor: AlwaysStoppedAnimation(petal.colors.accent),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${formatDuration(pos)} / ${formatDuration(dur)}', style: petal.text.meta),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayPause extends StatelessWidget {
  final bool playing;
  final bool buffering;
  final VoidCallback onTap;
  const _MiniPlayPause({required this.playing, required this.buffering, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return IconButton(
      icon: buffering
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: petal.colors.ink))
          : Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 28),
      color: petal.colors.ink,
      onPressed: buffering ? null : onTap,
    );
  }
}
