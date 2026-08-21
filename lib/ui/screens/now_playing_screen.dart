import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/track_extensions.dart';
import '../../state/library_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/playback_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/duration_format.dart';
import '../../utils/ui_scale.dart';
import '../widgets/swipe_down_to_dismiss.dart';
import '../widgets/track_art.dart';
import '../widgets/waveform_seekbar.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petal = context.petal;
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final track = playback.current;

    if (track == null) {
      return Center(child: Text('Nothing playing yet.', style: petal.text.meta));
    }

    return SwipeDownToDismiss(
      // Same destination the down-arrow button below already goes to —
      // dragging the player down is just a second way to trigger it, not
      // a different behavior. AppShell only hides MiniPlayer while
      // AppSection.nowPlaying is showing, so leaving this section is what
      // makes the mini player (with the playlist visible behind/under it)
      // reappear — see app_shell.dart.
      onDismiss: () => ref.read(currentSectionProvider.notifier).state = AppSection.library,
      child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => ref.read(currentSectionProvider.notifier).state = AppSection.library,
            ),
          ),
          const Spacer(),
          TrackArt(
            track: track,
            size: 220 * UiScale.of(context),
            iconSize: 64,
            borderRadius: BorderRadius.circular(24),
          ),
          const SizedBox(height: 28),
          Text(track.title, style: petal.text.heroTitle.copyWith(fontSize: 24), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(track.artist, style: petal.text.heroSub, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          StreamBuilder<Duration>(
            stream: controller.player.positionStream,
            builder: (context, snapshot) {
              final pos = snapshot.data ?? Duration.zero;
              final dur = track.duration.inMilliseconds > 0 ? track.duration : (controller.player.duration ?? const Duration(seconds: 1));
              final progress = dur.inMilliseconds == 0 ? 0.0 : pos.inMilliseconds / dur.inMilliseconds;

              return Column(
                children: [
                  WaveformSeekBar(
                    seed: track.id,
                    progress: progress,
                    filledColor: petal.colors.ink,
                    unfilledColor: petal.colors.ink3,
                    onSeekFraction: (f) => controller.seek(dur * f),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(pos), style: petal.text.meta),
                      Text(formatDuration(dur), style: petal.text.meta),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(track.isFavorite ? Icons.favorite : Icons.favorite_border),
                color: track.isFavorite ? petal.colors.ink : petal.colors.ink2,
                iconSize: 22,
                onPressed: () => ref.read(libraryControllerProvider.notifier).toggleFavorite(track),
              ),
              const SizedBox(width: 12),
              IconButton(icon: const Icon(Icons.skip_previous), iconSize: 30, onPressed: controller.previous),
              const SizedBox(width: 8),
              _BigPlayPause(playing: playback.isPlaying, buffering: playback.isBuffering, onTap: controller.togglePlayPause),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.skip_next), iconSize: 30, onPressed: controller.next),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.lyrics_outlined),
                iconSize: 22,
                color: petal.colors.ink2,
                onPressed: () => ref.read(currentSectionProvider.notifier).state = AppSection.lyrics,
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
      ),
    );
  }
}

class _BigPlayPause extends StatelessWidget {
  final bool playing;
  final bool buffering;
  final VoidCallback onTap;
  const _BigPlayPause({required this.playing, required this.buffering, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Material(
      color: petal.colors.accent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: buffering ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: buffering
              ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: petal.colors.accentInk))
              : Icon(playing ? Icons.pause : Icons.play_arrow, size: 28, color: petal.colors.accentInk),
        ),
      ),
    );
  }
}
