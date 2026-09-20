import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'glass_surface.dart';

class HeroBanner extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback? onPlay;

  const HeroBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.showBack = false,
    this.onBack,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        height: 190,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(PetalTheme.radiusHero),
          padding: const EdgeInsets.all(24),
          tint: petal.colors.surface.withOpacity(0.78),
          child: SizedBox.expand(
            child: Stack(
              children: [
                if (showBack)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: petal.colors.ink),
                      onPressed: onBack,
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              eyebrow.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: petal.colors.accent,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: petal.colors.ink,
                                letterSpacing: -0.8,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: petal.colors.ink2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onPlay != null)
                        Material(
                          color: petal.colors.accent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onPlay,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Icon(
                                Icons.play_arrow,
                                color: petal.colors.accentInk,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                    ],
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
