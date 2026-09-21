import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../data/db/app_database.dart';
import '../../data/models/track_extensions.dart';
import '../../data/services/window/window_service.dart';
import '../../state/library_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/playback_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/duration_format.dart';
import '../../utils/lyric_sync.dart';
import '../widgets/glass_surface.dart';
import '../widgets/animated_glass_backdrop.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/group_playback_sheet.dart';
import '../widgets/swipe_down_to_dismiss.dart';
import '../widgets/track_art.dart';

enum _PlayerPanel { lyrics, queue }

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  _PlayerPanel _panel = _PlayerPanel.lyrics;

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final track = playback.current;

    if (track == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq_rounded, size: 52, color: petal.colors.ink3),
            const SizedBox(height: 14),
            Text('Choose a song to start listening', style: petal.text.sectionTitle),
            const SizedBox(height: 6),
            Text('Your full player, lyrics, and queue will appear here.', style: petal.text.meta),
          ],
        ),
      );
    }

    return ColoredBox(
      color: petal.colors.ground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedGlassBackdrop(),
          SwipeDownToDismiss(
            onDismiss: _close,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                return Column(
                  children: [
                    _PlayerHeader(track: track, onClose: _close),
                    Expanded(
                      child: wide
                          ? _DesktopPlayer(
                              track: track,
                              playback: playback,
                              controller: controller,
                              panel: _panel,
                              onPanelChanged: _setPanel,
                            )
                          : _CompactPlayer(
                              track: track,
                              playback: playback,
                              controller: controller,
                              panel: _panel,
                              onPanelChanged: _setPanel,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _setPanel(_PlayerPanel panel) => setState(() => _panel = panel);

  void _close() => ref.read(currentSectionProvider.notifier).state = AppSection.library;
}

class _PlayerHeader extends StatelessWidget {
  final Track track;
  final VoidCallback onClose;

  const _PlayerHeader({required this.track, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final width = MediaQuery.sizeOf(context).width;
    final roomy = width >= 620;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        tint: petal.colors.surface.withOpacity(.58),
        child: Row(
        children: [
          IconButton(
            tooltip: 'Close player',
            onPressed: onClose,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 34),
          ),
          Expanded(
            child: Column(
              children: [
                Text('NOW PLAYING', style: petal.text.meta.copyWith(letterSpacing: 1.4)),
                Text(
                  track.album.isEmpty ? 'Petal library' : track.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: petal.text.miniTitle,
                ),
              ],
            ),
          ),
          if (roomy)
            IconButton(
              tooltip: 'Listen Together',
              onPressed: () => GroupPlaybackSheet.show(context),
              iconSize: 25,
              icon: const Icon(Icons.speaker_group_outlined),
            ),
          if (roomy)
            IconButton(
              tooltip: 'Equalizer',
              onPressed: () => EqualizerSheet.show(context),
              iconSize: 25,
              icon: const Icon(Icons.tune_rounded),
            ),
          IconButton(
            tooltip: 'Full screen',
            onPressed: WindowService.toggleFullscreen,
            iconSize: 28,
            icon: const Icon(Icons.fullscreen_rounded),
          ),
          IconButton(
            tooltip: 'More options',
            onPressed: () {},
            iconSize: 26,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
        ),
      ),
    );
  }
}

class _DesktopPlayer extends StatelessWidget {
  final Track track;
  final PlaybackState playback;
  final PlaybackController controller;
  final _PlayerPanel panel;
  final ValueChanged<_PlayerPanel> onPanelChanged;

  const _DesktopPlayer({
    required this.track,
    required this.playback,
    required this.controller,
    required this.panel,
    required this.onPanelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: _SpringReveal(
              child: GlassSurface(
                borderRadius: BorderRadius.circular(30),
                padding: const EdgeInsets.fromLTRB(30, 24, 22, 18),
                tint: petal.colors.surface.withOpacity(.62),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lyrics_rounded, color: petal.colors.accent, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          panel == _PlayerPanel.lyrics ? 'Lyrics' : 'Up next',
                          style: petal.text.sectionTitle.copyWith(fontSize: 22),
                        ),
                        const Spacer(),
                        _PanelSelector(selected: panel, onChanged: onPanelChanged, compact: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutBack,
                        child: panel == _PlayerPanel.lyrics
                            ? _InlineLyrics(
                                key: const ValueKey('desktop-lyrics'),
                                track: track,
                                playback: playback,
                                controller: controller,
                                spacious: true,
                              )
                            : _QueuePanel(
                                key: const ValueKey('desktop-queue'),
                                playback: playback,
                                controller: controller,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: _SpringReveal(
              delay: const Duration(milliseconds: 70),
              child: GlassSurface(
                borderRadius: BorderRadius.circular(30),
                padding: const EdgeInsets.fromLTRB(30, 22, 30, 24),
                tint: petal.colors.surface.withOpacity(.66),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final artSize = math.min(
                      math.min(constraints.maxWidth * .76, constraints.maxHeight * .50),
                      470.0,
                    ).clamp(250.0, 470.0).toDouble();
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: _SwipeableArtwork(
                              track: track,
                              controller: controller,
                              size: artSize,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              children: [
                                _TrackDetails(track: track, centered: true, large: true),
                                const SizedBox(height: 12),
                                _Transport(
                                  playback: playback,
                                  controller: controller,
                                  maxWidth: 500,
                                  large: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpringReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _SpringReveal({required this.child, this.delay = Duration.zero});

  @override
  State<_SpringReveal> createState() => _SpringRevealState();
}

class _SpringRevealState extends State<_SpringReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(vsync: this);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.animateWith(
          SpringSimulation(const SpringDescription(mass: 1, stiffness: 230, damping: 24), 0, 1, 0),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = _controller.value.clamp(0.0, 1.0).toDouble();
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 22),
            child: Transform.scale(scale: .97 + value * .03, child: child),
          ),
        );
      },
    );
  }
}

class _CompactPlayer extends StatelessWidget {
  final Track track;
  final PlaybackState playback;
  final PlaybackController controller;
  final _PlayerPanel panel;
  final ValueChanged<_PlayerPanel> onPanelChanged;

  const _CompactPlayer({
    required this.track,
    required this.playback,
    required this.controller,
    required this.panel,
    required this.onPanelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = math.max(
          190.0,
          math.min(constraints.maxWidth - 56, constraints.maxHeight * .46),
        ).toDouble();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          children: [
            _SpringReveal(
              child: Center(
                child: _SwipeableArtwork(track: track, controller: controller, size: artSize),
              ),
            ),
            const SizedBox(height: 20),
            GlassSurface(
              borderRadius: BorderRadius.circular(26),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                children: [
                  _TrackDetails(track: track),
                  const SizedBox(height: 12),
                  _Transport(playback: playback, controller: controller),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _PanelSelector(selected: panel, onChanged: onPanelChanged),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: _PlayerPanelBody(
                panel: panel,
                track: track,
                playback: playback,
                controller: controller,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SwipeableArtwork extends StatelessWidget {
  final Track track;
  final PlaybackController controller;
  final double size;

  const _SwipeableArtwork({required this.track, required this.controller, required this.size});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -250) controller.next();
        if (velocity > 250) controller.previous();
      },
      // AppShell switches sections in place rather than pushing Navigator
      // routes, so a Hero has no valid route flight here. Keeping one around
      // caused the artwork subtree to detach during desktop fullscreen metric
      // changes, leaving a blank player until another rebuild.
      child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.28),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: TrackArt(
            track: track,
            size: size,
            iconSize: size * .24,
            borderRadius: BorderRadius.circular(28),
          ),
        ),
    );
  }
}

class _TrackDetails extends ConsumerWidget {
  final Track track;
  final bool centered;
  final bool large;
  const _TrackDetails({required this.track, this.centered = false, this.large = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petal = context.petal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: petal.text.heroTitle.copyWith(fontSize: large ? 30 : 25),
              ),
              const SizedBox(height: 4),
              Text(
                track.artist,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: petal.text.heroSub.copyWith(fontSize: large ? 18 : 16),
              ),
              if (track.album.isNotEmpty)
                Text(
                  track.album,
                  textAlign: centered ? TextAlign.center : TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: petal.text.meta.copyWith(fontSize: large ? 14 : null),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: track.isFavorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: () => ref.read(libraryControllerProvider.notifier).toggleFavorite(track),
          icon: Icon(track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
          color: track.isFavorite ? petal.colors.accent : petal.colors.ink2,
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  final PlaybackState playback;
  final PlaybackController controller;
  final double maxWidth;
  final bool large;
  const _Transport({
    required this.playback,
    required this.controller,
    this.maxWidth = 460,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final track = playback.current!;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        children: [
        StreamBuilder<Duration?>(
          stream: controller.player.durationStream,
          builder: (context, durationSnapshot) => StreamBuilder<Duration>(
            stream: controller.player.positionStream,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              final duration = durationSnapshot.data ??
                  (track.duration.inMilliseconds > 0 ? track.duration : const Duration(seconds: 1));
              final max = math.max(1, duration.inMilliseconds).toDouble();
              final remaining = duration > position ? duration - position : Duration.zero;
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: position.inMilliseconds.clamp(0, max.toInt()).toDouble(),
                      max: max,
                      onChanged: (value) => controller.seek(Duration(milliseconds: value.round())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDuration(position), style: petal.text.meta),
                        Text('-${formatDuration(remaining)}', style: petal.text.meta),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: playback.shuffleEnabled ? 'Shuffle on' : 'Shuffle off',
              onPressed: controller.toggleShuffle,
              color: playback.shuffleEnabled ? petal.colors.accent : petal.colors.ink2,
              icon: const Icon(Icons.shuffle_rounded),
            ),
            IconButton(
              onPressed: controller.previous,
              iconSize: large ? 42 : 35,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            _PlayButton(playback: playback, controller: controller, large: large),
            IconButton(
              onPressed: controller.next,
              iconSize: large ? 42 : 35,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            IconButton(
              tooltip: _loopLabel(playback.loopMode),
              onPressed: controller.cycleLoopMode,
              color: playback.loopMode == LoopMode.off ? petal.colors.ink2 : petal.colors.accent,
              icon: Icon(playback.loopMode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<double>(
          stream: controller.player.volumeStream,
          initialData: controller.player.volume,
          builder: (context, snapshot) {
            final volume = snapshot.data ?? 1;
            return Center(
              child: SizedBox(
                width: math.min(maxWidth * .62, 280.0).toDouble(),
                child: Row(
                  children: [
                    Icon(
                      volume == 0 ? Icons.volume_off_rounded : Icons.volume_down_rounded,
                      size: 18,
                      color: petal.colors.ink3,
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(trackHeight: 2),
                        child: Slider(value: volume, onChanged: controller.setVolume),
                      ),
                    ),
                    Icon(Icons.volume_up_rounded, size: 18, color: petal.colors.ink3),
                  ],
                ),
              ),
            );
          },
        ),
        ],
      ),
    );
  }

  static String _loopLabel(LoopMode mode) => switch (mode) {
        LoopMode.off => 'Repeat off',
        LoopMode.all => 'Repeat queue',
        LoopMode.one => 'Repeat one',
      };
}

class _PlayButton extends StatelessWidget {
  final PlaybackState playback;
  final PlaybackController controller;
  final bool large;
  const _PlayButton({required this.playback, required this.controller, this.large = false});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Material(
      color: petal.colors.accent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: playback.isBuffering ? null : controller.togglePlayPause,
        child: SizedBox(
          width: large ? 74 : 64,
          height: large ? 74 : 64,
          child: playback.isBuffering
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: petal.colors.accentInk),
                )
              : Icon(
                  playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: large ? 45 : 38,
                  color: petal.colors.accentInk,
                ),
        ),
      ),
    );
  }
}

class _PanelSelector extends StatelessWidget {
  final _PlayerPanel selected;
  final ValueChanged<_PlayerPanel> onChanged;
  final bool compact;
  const _PanelSelector({required this.selected, required this.onChanged, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_PlayerPanel>(
      segments: compact
          ? const [
              ButtonSegment(value: _PlayerPanel.lyrics, icon: Icon(Icons.lyrics_outlined)),
              ButtonSegment(value: _PlayerPanel.queue, icon: Icon(Icons.queue_music_rounded)),
            ]
          : const [
              ButtonSegment(value: _PlayerPanel.lyrics, icon: Icon(Icons.lyrics_outlined), label: Text('Lyrics')),
              ButtonSegment(value: _PlayerPanel.queue, icon: Icon(Icons.queue_music_rounded), label: Text('Up next')),
            ],
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
      showSelectedIcon: false,
    );
  }
}

class _PlayerPanelBody extends StatelessWidget {
  final _PlayerPanel panel;
  final Track track;
  final PlaybackState playback;
  final PlaybackController controller;

  const _PlayerPanelBody({
    required this.panel,
    required this.track,
    required this.playback,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: panel == _PlayerPanel.lyrics
            ? _InlineLyrics(
                key: const ValueKey('lyrics'),
                track: track,
                playback: playback,
                controller: controller,
              )
            : _QueuePanel(
                key: const ValueKey('queue'),
                playback: playback,
                controller: controller,
              ),
      ),
    );
  }
}

class _InlineLyrics extends StatefulWidget {
  final Track track;
  final PlaybackState playback;
  final PlaybackController controller;
  final bool spacious;
  const _InlineLyrics({
    super.key,
    required this.track,
    required this.playback,
    required this.controller,
    this.spacious = false,
  });

  @override
  State<_InlineLyrics> createState() => _InlineLyricsState();
}

class _InlineLyricsState extends State<_InlineLyrics> {
  final _scrollController = ItemScrollController();
  int _lastActive = -1;

  @override
  void didUpdateWidget(covariant _InlineLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) _lastActive = -1;
  }

  void _keepActiveVisible(int active) {
    if (active < 0 || active == _lastActive) return;
    if (!_scrollController.isAttached) {
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _keepActiveVisible(active);
      });
      return;
    }
    _lastActive = active;
    _scrollController.scrollTo(
      index: active,
      alignment: widget.spacious ? .40 : .30,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final lyrics = widget.playback.lyrics;
    if (lyrics == null) return const Center(child: CircularProgressIndicator());
    if (!lyrics.found) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_download_outlined, size: 34, color: petal.colors.ink3),
            const SizedBox(height: 10),
            Text('No embedded or online lyrics found.', style: petal.text.meta),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.controller.reloadLyrics,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Search online again'),
            ),
          ],
        ),
      );
    }
    if (!lyrics.isSynced) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Text(
          lyrics.plainText ?? '',
          style: petal.text.lyricLine.copyWith(
            color: petal.colors.ink,
            fontSize: widget.spacious ? 27 : null,
            height: widget.spacious ? 1.65 : null,
          ),
        ),
      );
    }
    return StreamBuilder<Duration>(
      stream: widget.controller.player.positionStream,
      builder: (context, snapshot) {
        final position = (snapshot.data ?? Duration.zero) +
            Duration(milliseconds: widget.playback.lyricsOffsetMs);
        final active = currentLyricIndex(lyrics.synced, position);
        WidgetsBinding.instance.addPostFrameCallback((_) => _keepActiveVisible(active));
        return ScrollablePositionedList.builder(
          itemScrollController: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          itemCount: lyrics.synced.length,
          itemBuilder: (context, index) {
            final line = lyrics.synced[index];
            final selected = index == active;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => widget.controller.seekToLyricLine(line),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  style: selected
                      ? petal.text.lyricLineActive.copyWith(
                          fontSize: widget.spacious ? 38 : null,
                          height: widget.spacious ? 1.35 : null,
                        )
                      : petal.text.lyricLine.copyWith(
                          fontSize: widget.spacious ? 29 : null,
                          height: widget.spacious ? 1.55 : null,
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

class _QueuePanel extends StatelessWidget {
  final PlaybackState playback;
  final PlaybackController controller;
  const _QueuePanel({super.key, required this.playback, required this.controller});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    if (playback.queue.isEmpty) {
      return Center(child: Text('Your queue is empty.', style: petal.text.meta));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: playback.queue.length,
      itemBuilder: (context, index) {
        final item = playback.queue[index];
        final current = index == playback.index;
        return ListTile(
          selected: current,
          selectedTileColor: petal.colors.surface2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: TrackArt(
            track: item,
            size: 42,
            iconSize: 17,
            borderRadius: BorderRadius.circular(7),
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(item.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: current
              ? Icon(Icons.graphic_eq_rounded, color: petal.colors.accent)
              : Text(formatDuration(item.duration), style: petal.text.meta),
          onTap: () => controller.playAt(index),
        );
      },
    );
  }
}
