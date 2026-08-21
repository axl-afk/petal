import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/nav_controller.dart';
import '../../utils/breakpoints.dart';
import '../screens/add_source_screen.dart';
import '../screens/library_screen.dart';
import '../screens/lyrics_screen.dart';
import '../screens/now_playing_screen.dart';
import '../screens/settings_screen.dart';
import 'mini_player.dart';
import 'right_rail.dart';
import 'side_rail.dart';
import 'top_bar.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(currentSectionProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isMobile = Breakpoints.isMobile(width);
            final showRail = !isMobile;
            final showRightRail = Breakpoints.isDesktop(width);

            return Column(
              children: [
                TopBar(isMobile: isMobile),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showRail) const SideRail(),
                      Expanded(child: _MainContent(section: section)),
                      if (showRightRail) const RightRail(),
                    ],
                  ),
                ),
                if (section != AppSection.nowPlaying) const MiniPlayer(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MainContent extends StatelessWidget {
  final AppSection section;
  const _MainContent({required this.section});

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case AppSection.library:
        return const LibraryScreen();
      case AppSection.nowPlaying:
        return const NowPlayingScreen();
      case AppSection.lyrics:
        return const LyricsScreen();
      case AppSection.addSource:
        return const AddSourceScreen();
      case AppSection.settings:
        return const SettingsScreen();
    }
  }
}
