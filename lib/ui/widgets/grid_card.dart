import 'package:flutter/material.dart';

import 'dart:typed_data';

import '../../theme/app_theme.dart';
import 'track_art.dart';

class GridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Uint8List? imageBytes;
  final String? artworkUrl;

  const GridCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageBytes,
    this.artworkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    // Give each collection a stable color without relying on editorial art.
    // Actual playlist artwork always takes priority when available.
    final hue =
        (title.runes.fold<int>(0, (value, rune) => value * 31 + rune) % 360)
            .toDouble();
    final wash = HSVColor.fromAHSV(1, hue, .58, .68).toColor();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(PetalTheme.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(PetalTheme.radiusCard),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [wash, wash.withOpacity(.48)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.22),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) => imageBytes != null
                      ? Image.memory(
                          imageBytes!,
                          fit: BoxFit.cover,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                        )
                      : artworkUrl != null && artworkUrl!.isNotEmpty
                      ? TrackArt(
                          track: null,
                          artworkUrl: artworkUrl,
                          size: constraints.maxWidth,
                          borderRadius: BorderRadius.circular(14),
                        )
                      : Icon(
                          icon,
                          size: (constraints.maxWidth * .25).clamp(44.0, 110.0),
                          color: Colors.white.withOpacity(.92),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: petal.text.cardTitle,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: petal.text.cardSubtitle,
            ),
          ],
        ),
      ),
    );
  }
}
