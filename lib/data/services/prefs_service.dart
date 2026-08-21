import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';

enum ThemeMode2 { light, dark, auto }

/// Small, non-library settings that live outside the drift database:
/// signed-in session, theme choice, and cached "which platform am I on"
/// niceties. Library data (tracks/playlists/sources) always lives in
/// AppDatabase — this is intentionally just for app-shell state.
class PrefsService {
  static const _kSession = 'petal_session_v1';
  static const _kTheme = 'petal_theme_v1';
  static const _kOnboarded = 'petal_onboarded_v1';

  final SharedPreferences _prefs;
  PrefsService(this._prefs);

  static Future<PrefsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsService(prefs);
  }

  AuthSession? loadSession() {
    final raw = _prefs.getString(_kSession);
    if (raw == null) return null;
    try {
      return AuthSession.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(AuthSession session) =>
      _prefs.setString(_kSession, AuthSession.encode(session));

  Future<void> clearSession() => _prefs.remove(_kSession);

  ThemeMode2 loadThemeMode() {
    final raw = _prefs.getString(_kTheme);
    return ThemeMode2.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode2.auto,
    );
  }

  Future<void> saveThemeMode(ThemeMode2 mode) => _prefs.setString(_kTheme, mode.name);

  /// Whether the first-run onboarding screen (sign in vs. local-only, plus
  /// the Android audio-permission prompt) has already been shown on this
  /// device — see OnboardingController / ui/screens/onboarding_screen.dart.
  bool loadHasOnboarded() => _prefs.getBool(_kOnboarded) ?? false;

  Future<void> saveHasOnboarded() => _prefs.setBool(_kOnboarded, true);
}
