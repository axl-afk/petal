import 'package:flutter/material.dart';

import '../../data/db/app_database.dart';
import '../../theme/app_theme.dart';
import 'track_art_local.dart';

/// Renders a track's artwork when it has any — a local file path (from an
/// imported local file's embedded cover art) or a remote http(s) URL — and
/// falls back to a plain music-note placeholder otherwise, or if the image
/// fails to load (a moved/deleted local artwork file, a broken remote URL).
class TrackArt extends StatelessWidget {
  final Track? track;
  final double size;
  final double iconSize;
  final BorderRadius? borderRadius;

  const TrackArt({
    super.key,
    required this.track,
    required this.size,
    this.iconSize = 18,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final radius = borderRadius ?? BorderRadius.circular(8);
    final url = track?.artworkUrl;

    Widget placeholder() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: petal.colors.surface2, borderRadius: radius),
          child: Icon(Icons.music_note, size: iconSize, color: petal.colors.ink3),
        );

    if (url == null || url.isEmpty) return placeholder();

    final isRemote = url.startsWith('http://') || url.startsWith('https://');
    if (isRemote) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder(),
        ),
      );
    }

    return buildLocalTrackArt(path: url, size: size, radius: radius, placeholder: placeholder);
  }
}
