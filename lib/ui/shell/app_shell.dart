import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../data/services/window/window_service.dart';
import '../../l10n/app_localizations.dart';
import '../../state/auth_controller.dart';
import '../../state/cloud_sync_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/playback_controller.dart';
import '../../utils/breakpoints.dart';
import '../../utils/ui_scale.dart';
import '../../theme/app_theme.dart';
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
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.75, -0.9),
            radius: 1.55,
            colors: [
              context.petal.colors.accent.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.13 : 0.10,
              ),
              context.petal.colors.ground,
            ],
          ),
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: WindowService.rebuildTick,
          builder: (context, _, __) => SafeArea(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.space): () {
                  if (!_editingText()) {
                    ref.read(playbackControllerProvider.notifier).togglePlayPause();
                  }
                },
                const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
                    () => ref.read(playbackControllerProvider.notifier).next(),
                const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
                    () => ref.read(playbackControllerProvider.notifier).previous(),
              },
              child: Focus(
                autofocus: true,
                child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isMobile = Breakpoints.isMobile(width);
                final immersive = section == AppSection.nowPlaying ||
                    section == AppSection.lyrics;
                final showRail = !isMobile;
                final showRightRail = Breakpoints.isDesktop(width);
                final scale = UiScale.forWidth(width);

                return UiScale(
                  value: scale,
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: immersive
                        // Fullscreen window changes can report several
                        // intermediate sizes. Swapping two full-screen trees
                        // during those frames used to leave only the outgoing
                        // (transparent) AnimatedSwitcher child visible. Keep
                        // one stable, opaque repaint boundary instead.
                        ? ColoredBox(
                            color: context.petal.colors.ground,
                            child: RepaintBoundary(
                              child: KeyedSubtree(
                                key: ValueKey(section),
                                child: _MainContent(section: section),
                              ),
                            ),
                          )
                        : Column(
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
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.02),
                                            end: Offset.zero,
                                          ).animate(animation),
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
                        const MiniPlayer(),
                        if (isMobile) const _MobileNavigation(),
                      ],
                    ),
                  ),
                );
              },
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _editingText() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context?.widget is EditableText ||
        context?.findAncestorWidgetOfExactType<EditableText>() != null;
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

class _MobileNavigation extends ConsumerWidget {
  const _MobileNavigation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(currentSectionProvider);
    final l10n = AppLocalizations.of(context)!;
    final selected = switch (section) {
      AppSection.library => 0,
      AppSection.nowPlaying || AppSection.lyrics => 1,
      AppSection.addSource => 2,
      AppSection.settings => 3,
    };
    return NavigationBar(
      height: 66,
      backgroundColor: context.petal.colors.surface.withOpacity(0.88),
      indicatorColor: context.petal.colors.accent.withOpacity(0.22),
      selectedIndex: selected,
      onDestinationSelected: (index) {
        ref.read(currentSectionProvider.notifier).state = switch (index) {
          0 => AppSection.library,
          1 => AppSection.nowPlaying,
          2 => AppSection.addSource,
          _ => AppSection.settings,
        };
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.library_music_outlined),
          selectedIcon: const Icon(Icons.library_music),
          label: l10n.library,
        ),
        NavigationDestination(
          icon: const Icon(Icons.album_outlined),
          selectedIcon: const Icon(Icons.album),
          label: l10n.playing,
        ),
        NavigationDestination(
          icon: const Icon(Icons.add_circle_outline),
          selectedIcon: const Icon(Icons.add_circle),
          label: l10n.add,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: l10n.settings,
        ),
      ],
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
