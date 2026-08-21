import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/prefs_service.dart';
import 'providers.dart';

/// Whether the first-run onboarding screen has already been completed on
/// this device — gates PetalApp's `home:` (see app.dart). Same shape as
/// ThemeController (state seeded from PrefsService at construction, writes
/// through on change) so the rest of the app has one consistent pattern for
/// "small persisted flag that also needs to be reactive in the widget
/// tree", rather than a plain PrefsService read that wouldn't trigger a
/// rebuild when it changes.
class OnboardingController extends StateNotifier<bool> {
  final PrefsService _prefs;
  OnboardingController(this._prefs) : super(_prefs.loadHasOnboarded());

  Future<void> complete() async {
    state = true;
    await _prefs.saveHasOnboarded();
  }
}

final onboardingControllerProvider = StateNotifierProvider<OnboardingController, bool>((ref) {
  return OnboardingController(ref.watch(prefsServiceProvider));
});
