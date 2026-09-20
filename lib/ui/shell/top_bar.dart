import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../state/library_controller.dart';
import '../../state/nav_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_scale.dart';
import '../widgets/profile_avatar.dart';

class TopBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool isMobile;
  const TopBar({super.key, required this.isMobile});

  @override
  Size get preferredSize => const Size.fromHeight(PetalTheme.topBarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petal = context.petal;
    final l10n = AppLocalizations.of(context)!;
    final section = ref.watch(currentSectionProvider);
    final libraryState = ref.watch(libraryControllerProvider);
    final session = ref.watch(authControllerProvider).session;

    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.asset(
            'assets/icon/icon_square.png',
            width: 24,
            height: 24,
          ),
        ),
        const SizedBox(width: 8),
        Text('Petal', style: petal.text.brand),
      ],
    );

    final search = SizedBox(
      width: isMobile ? double.infinity : 240,
      height: 36,
      child: TextField(
        onChanged: (q) {
          ref.read(currentSectionProvider.notifier).state = AppSection.library;
          ref.read(libraryControllerProvider.notifier).setSearchQuery(q);
        },
        style: TextStyle(fontSize: 13.5, color: petal.colors.ink),
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.searchLibrary,
          hintStyle: TextStyle(color: petal.colors.ink3, fontSize: 13.5),
          prefixIcon: Icon(Icons.search, size: 18, color: petal.colors.ink3),
          filled: true,
          fillColor: petal.colors.surface2,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Add source',
          icon: const Icon(Icons.add_circle_outline, size: 20),
          color: section == AppSection.addSource
              ? petal.colors.ink
              : petal.colors.ink2,
          onPressed: () => ref.read(currentSectionProvider.notifier).state =
              AppSection.addSource,
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined, size: 20),
          color: section == AppSection.settings
              ? petal.colors.ink
              : petal.colors.ink2,
          onPressed: () => ref.read(currentSectionProvider.notifier).state =
              AppSection.settings,
        ),
        ProfileAvatar(
          session: session,
          radius: 15,
          onTap: () => ref.read(currentSectionProvider.notifier).state =
              AppSection.settings,
        ),
      ],
    );

    final container = Container(
      color: petal.colors.surface.withOpacity(0.72),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 24,
        vertical: isMobile ? 10 : 0,
      ),
      constraints: BoxConstraints(
        minHeight: PetalTheme.topBarHeight * UiScale.of(context),
      ),
      child: isMobile
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [brand, actions],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 8),
                    PopupMenuButton<LibraryTab>(
                      tooltip: 'Library view',
                      onSelected: (tab) {
                        ref.read(currentSectionProvider.notifier).state =
                            AppSection.library;
                        ref
                            .read(libraryControllerProvider.notifier)
                            .setTab(tab);
                      },
                      itemBuilder: (context) => LibraryTab.values
                          .map(
                            (tab) => PopupMenuItem(
                              value: tab,
                              child: Text(_labelFor(context, tab)),
                            ),
                          )
                          .toList(),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: petal.colors.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _labelFor(context, libraryState.tab),
                              style: petal.text.tabLabelActive,
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.expand_more, size: 17),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                brand,
                const Spacer(),
                search,
                const SizedBox(width: 8),
                actions,
              ],
            ),
    );

    return container;
  }

  String _labelFor(BuildContext context, LibraryTab tab) {
    final l10n = AppLocalizations.of(context)!;
    return switch (tab) {
      LibraryTab.songs => l10n.songs,
      LibraryTab.artists => l10n.artists,
      LibraryTab.albums => l10n.albums,
      LibraryTab.genres => l10n.genres,
      LibraryTab.playlists => l10n.playlists,
      LibraryTab.favorites => l10n.favoriteSongs,
    };
  }
}
