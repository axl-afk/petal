import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/onboarding_controller.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/shell/app_shell.dart';

class PetalApp extends ConsumerWidget {
  const PetalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(flutterThemeModeProvider);
    // First-run gate — see onboarding_controller.dart. Reactive rather than
    // a one-shot PrefsService read: OnboardingController.complete() flips
    // this provider's state, which is what actually swaps `home:` from
    // OnboardingScreen to AppShell without needing a Navigator push (this
    // app doesn't otherwise use routes at all — see nav_controller.dart).
    final hasOnboarded = ref.watch(onboardingControllerProvider);

    return MaterialApp(
      title: 'Petal',
      debugShowCheckedModeBanner: false,
      theme: petalLightTheme,
      darkTheme: petalDarkTheme,
      themeMode: themeMode,
      home: hasOnboarded ? const AppShell() : const OnboardingScreen(),
    );
  }
}
