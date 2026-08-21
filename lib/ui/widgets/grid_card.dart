import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class GridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const GridCard({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});

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
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: petal.colors.surface2, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: petal.colors.ink2),
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
