import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/track_extensions.dart';
import '../../state/playback_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/duration_format.dart';
import '../../utils/ui_scale.dart';
import '../widgets/track_art.dart';

class RightRail extends ConsumerWidget {
  const RightRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petal = context.petal;
    final playback = ref.watch(playbackControllerProvider);
    final upNext = playback.queue.isEmpty
        ? const []
        : playback.queue.sublist((playback.index + 1).clamp(0, playback.queue.length));

    return Container(
      width: PetalTheme.rightRailWidth * UiScale.of(context),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: petal.colors.surface.withOpacity(0.5),
        border: Border(left: BorderSide(color: petal.colors.hairline)),
      ),
      child: ListView(
        children: [
          Text('Up next', style: petal.text.sectionTitle),
          const SizedBox(height: 12),
          if (upNext.isEmpty)
            Text('Nothing queued — play a song to start building a queue.', style: petal.text.meta)
          else
            ...upNext.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    TrackArt(track: t, size: 36, iconSize: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: petal.text.miniTitle),
                          Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: petal.text.miniArtist),
                        ],
                      ),
                    ),
                    Text(formatDuration(t.duration), style: petal.text.meta),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          _TipCard(),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: petal.colors.surface2, borderRadius: BorderRadius.circular(PetalTheme.radiusCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 18, color: petal.colors.ink2),
          const SizedBox(height: 10),
          Text('Grow your library', style: petal.text.cardTitle),
          const SizedBox(height: 4),
          Text(
            'Paste a public Google Drive or OneDrive link from Add Source to stream straight into Petal — no upload needed.',
            style: petal.text.cardSubtitle,
          ),
        ],
      ),
    );
  }
}
