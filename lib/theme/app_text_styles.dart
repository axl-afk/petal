import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  final AppColors c;
  const AppTextStyles(this.c);

  TextStyle get brand => TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink, letterSpacing: -0.2);
  TextStyle get tabLabel => TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink2);
  TextStyle get tabLabelActive => tabLabel.copyWith(color: c.ink);
  TextStyle get heroEyebrow => TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink2, letterSpacing: 0.4);
  TextStyle get heroTitle => TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: -0.6, height: 1.05);
  TextStyle get heroSub => TextStyle(fontSize: 13.5, color: c.ink2);
  TextStyle get sectionTitle => TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink);
  TextStyle get trackTitle => TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink);
  TextStyle get trackTitleCurrent => trackTitle.copyWith(color: c.accent);
  TextStyle get trackSubtitle => TextStyle(fontSize: 12, color: c.ink2);
  TextStyle get meta => TextStyle(fontSize: 12, color: c.ink3);
  TextStyle get cardTitle => TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink);
  TextStyle get cardSubtitle => TextStyle(fontSize: 12, color: c.ink2);
  TextStyle get miniTitle => TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink);
  TextStyle get miniArtist => TextStyle(fontSize: 11.5, color: c.ink2);
  TextStyle get lyricLine => TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: c.ink3, height: 1.55);
  TextStyle get lyricLineActive => lyricLine.copyWith(color: c.ink, fontSize: 22);
  TextStyle get settingsGroupTitle => TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink2, letterSpacing: 0.3);
}
