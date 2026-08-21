import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/window/window_service.dart';
import '../../state/auth_controller.dart';
import '../../state/cloud_sync_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/playback_controller.dart';
import '../../utils/breakpoints.dart';
import '../../utils/ui_scale.dart';
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

    // Both of these are set into state already (playback_controller.dart,
    // auth_controller.dart) but previously only ever *read* on the Settings
    // screen and the Add Source link-resolver form — clicking "Login" from
    // the top bar avatar, or having playback fail for any other reason,
    // produced no visible feedback at all: the app just looked frozen.
    // Listening here, at the one widget that's always mounted, means every
    // failure surfaces no matter which screen triggered it.
    ref.listen<PlaybackState>(playbackControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        _showErrorSnackBar(context, next.error!);
      }
    });
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        _showErrorSnackBar(context, next.error!);
      }
    });
    // Same idea for a failed Google Drive library backup/restore (see
    // cloud_sync_controller.dart) — otherwise a sync failure (expired
    // token, offline, a Drive API error) would happen silently in the
    // background with no way to know your library didn't actually back up.
    ref.listen<CloudSyncState>(cloudSyncControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        _showErrorSnackBar(context, 'Library backup: ${next.error!}');
      }
    });

    return Scaffold(
      // ValueListenableBuilder around the whole responsive tree: an
      // insurance rebuild on desktop window resize / macOS fullscreen
      // enter-or-leave (see WindowService.rebuildTick's doc comment for why
      // this is defensive, not a fix for a known engine bug) — a no-op
      // ValueNotifier that never changes on web/mobile, so this has zero
      // effect there.
      body: ValueListenableBuilder<int>(
        valueListenable: WindowService.rebuildTick,
        builder: (context, _, __) => SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isMobile = Breakpoints.isMobile(width);
            final showRail = !isMobile;
            final showRightRail = Breakpoints.isDesktop(width);
            final scale = UiScale.forWidth(width);

            return UiScale(
              value: scale,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: Column(
                  children: [
                    TopBar(isMobile: isMobile),
                    const Divider(height: 1),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showRail) const SideRail(),
                          Expanded(
                            // Cross-fades + a small upward slide between
                            // sections (library <-> now playing <-> lyrics
                            // <-> settings/add source) instead of an
                            // instant swap — the same nav model
                            // (currentSectionProvider, no Navigator routes)
                            // just with a transition. Keyed on `section` so
                            // AnimatedSwitcher treats each section as a
                            // distinct child and actually animates between
                            // them rather than rebuilding one in place.
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
                                  child: child,
                                ),
                              ),
                              child: KeyedSubtree(
                                key: ValueKey(section),
                                child: _MainContent(section: section),
                              ),
                            ),
                          ),
                          if (showRightRail) const RightRail(),
                        ],
                      ),
                    ),
                    if (section != AppSection.nowPlaying) const MiniPlayer(),
                  ],
                ),
              ),
            );
          },
        ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent.shade200,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
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
