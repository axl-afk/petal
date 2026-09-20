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
    return Material(
      color: petal.colors.surface,
      borderRadius: BorderRadius.circular(PetalTheme.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(PetalTheme.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: imageBytes == null ? 44 : double.infinity,
                height: imageBytes == null ? 44 : 96,
                decoration: BoxDecoration(color: petal.colors.surface2, borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: imageBytes == null
                    ? Icon(icon, size: 20, color: petal.colors.ink2)
                    : Image.memory(imageBytes!, fit: BoxFit.cover),
              ),
              const Spacer(),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: petal.text.cardTitle),
              const SizedBox(height: 2),
              Text(subtitle, style: petal.text.cardSubtitle),
            ],
          ),
        ),
      ),
    );
  }
}
