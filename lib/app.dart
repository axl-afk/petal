import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/theme_controller.dart';
import 'theme/app_theme.dart';
import 'ui/shell/app_shell.dart';

class PetalApp extends ConsumerWidget {
  const PetalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(flutterThemeModeProvider);

    return MaterialApp(
      title: 'Petal',
      debugShowCheckedModeBanner: false,
      theme: petalLightTheme,
      darkTheme: petalDarkTheme,
      themeMode: themeMode,
      home: const AppShell(),
    );
  }
}
