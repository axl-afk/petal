import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth_controller.dart';
import '../../state/library_controller.dart';
import '../../state/nav_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_scale.dart';

class TopBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool isMobile;
  const TopBar({super.key, required this.isMobile});

  @override
  Size get preferredSize => const Size.fromHeight(PetalTheme.topBarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petal = context.petal;
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

    final tabs = Wrap(
      spacing: 2,
      children: LibraryTab.values.map((tab) {
        final isActiveTab =
            section == AppSection.library &&
            libraryState.tab == tab &&
            !libraryState.filter.isActive;
        return _TabButton(
          label: _labelFor(tab),
          active: isActiveTab,
          onTap: () {
            ref.read(currentSectionProvider.notifier).state =
                AppSection.library;
            ref.read(libraryControllerProvider.notifier).setTab(tab);
          },
        );
      }).toList(),
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
          hintText: 'Search your library',
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
        GestureDetector(
          onTap: () => ref.read(currentSectionProvider.notifier).state =
              AppSection.settings,
          child: CircleAvatar(
            radius: 15,
            backgroundColor: petal.colors.surface2,
            child: session == null
                ? Icon(Icons.person_outline, size: 16, color: petal.colors.ink2)
                : Text(
                    session.email.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: petal.colors.ink,
                    ),
                  ),
          ),
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
                              child: Text(_labelFor(tab)),
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
                              _labelFor(libraryState.tab),
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
                const SizedBox(width: 20),
                tabs,
                const Spacer(),
                search,
                const SizedBox(width: 8),
                actions,
              ],
            ),
    );

    return container;
  }

  String _labelFor(LibraryTab tab) => switch (tab) {
    LibraryTab.songs => 'Songs',
    LibraryTab.artists => 'Artists',
    LibraryTab.genres => 'Genres',
    LibraryTab.playlists => 'Playlists',
    LibraryTab.favorites => 'Favorites',
  };
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Material(
      color: active ? petal.colors.surface2 : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: active ? petal.text.tabLabelActive : petal.text.tabLabel,
          ),
        ),
      ),
    );
  }
}
