import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../../theme/app_theme.dart';

class GridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Uint8List? imageBytes;

  const GridCard({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap, this.imageBytes});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    // Give each collection a stable color without relying on editorial art.
    // Actual playlist artwork always takes priority when available.
    final hue = (title.runes.fold<int>(0, (value, rune) => value * 31 + rune) % 360).toDouble();
    final wash = HSVColor.fromAHSV(1, hue, .58, .68).toColor();
    return Material(
      color: petal.colors.surface,
      borderRadius: BorderRadius.circular(PetalTheme.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(PetalTheme.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageBytes == null
                      ? Icon(icon, size: 44, color: Colors.white.withOpacity(.92))
                      : Image.memory(imageBytes!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 10),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: petal.text.cardTitle),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: petal.text.cardSubtitle),
            ],
          ),
        ),
      ),
    );
  }
}
