import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

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
    return Container(
      height: 190,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141216),
        borderRadius: BorderRadius.circular(PetalTheme.radiusHero),
      ),
      child: Stack(
        children: [
          if (showBack)
            Positioned(
              top: 0,
              left: 0,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 0.4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5, height: 1.05),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
                if (onPlay != null)
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onPlay,
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(Icons.play_arrow, color: Color(0xFF101012), size: 24),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
