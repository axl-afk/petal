import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/prefs_service.dart';
import 'providers.dart';

class ThemeController extends StateNotifier<ThemeMode2> {
  final PrefsService _prefs;
  ThemeController(this._prefs) : super(_prefs.loadThemeMode());

  Future<void> setMode(ThemeMode2 mode) async {
    state = mode;
    await _prefs.saveThemeMode(mode);
  }
}

final themeControllerProvider = StateNotifierProvider<ThemeController, ThemeMode2>((ref) {
  return ThemeController(ref.watch(prefsServiceProvider));
});

/// Maps Petal's own light/dark/auto choice onto Flutter's ThemeMode, kept as
/// a tiny separate provider so MaterialApp's `themeMode:` can watch just
/// this instead of re-deriving it inline.
final flutterThemeModeProvider = Provider<ThemeMode>((ref) {
  switch (ref.watch(themeControllerProvider)) {
    case ThemeMode2.light:
      return ThemeMode.light;
    case ThemeMode2.dark:
      return ThemeMode.dark;
    case ThemeMode2.auto:
      return ThemeMode.system;
  }
});
