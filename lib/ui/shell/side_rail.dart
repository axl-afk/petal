import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

import '../../data/models/auth_session.dart';
import '../../l10n/app_localizations.dart';
import '../../state/auth_controller.dart';
import '../../state/library_controller.dart';
import '../../state/nav_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_scale.dart';

class SideRail extends ConsumerWidget {
  const SideRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petal = context.petal;
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).session;
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final library = ref.watch(libraryControllerProvider);

    final localConnected = !kIsWeb;
    final driveConnected = session?.provider == AuthProviderKind.google;
    final oneDriveConnected = session?.provider == AuthProviderKind.microsoft;

    return Container(
      width: PetalTheme.railWidth * UiScale.of(context),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: petal.colors.surface.withOpacity(0.5),
        border: Border(right: BorderSide(color: petal.colors.hairline)),
      ),
      child: ListView(
        children: [
          _RailAction(
            icon: Icons.search_rounded,
            label: l10n.search,
            onTap: () => ref.read(currentSectionProvider.notifier).state =
                AppSection.library,
          ),
          _RailAction(
            icon: Icons.home_outlined,
            label: l10n.home,
            selected: !library.filter.isActive &&
                library.tab == LibraryTab.songs,
            onTap: () {
              ref.read(currentSectionProvider.notifier).state =
                  AppSection.library;
              ref
                  .read(libraryControllerProvider.notifier)
                  .setTab(LibraryTab.songs);
            },
          ),
          const SizedBox(height: 16),
          _SectionLabel(l10n.library.toUpperCase()),
          _LibraryRow(
            icon: Icons.favorite_outline_rounded,
            label: l10n.favoriteSongs,
            tab: LibraryTab.favorites,
            activeTab: library.tab,
          ),
          _LibraryRow(
            icon: Icons.music_note_rounded,
            label: l10n.songs,
            tab: LibraryTab.songs,
            activeTab: library.tab,
          ),
          _LibraryRow(
            icon: Icons.mic_none_rounded,
            label: l10n.artists,
            tab: LibraryTab.artists,
            activeTab: library.tab,
          ),
          _LibraryRow(
            icon: Icons.album_outlined,
            label: l10n.albums,
            tab: LibraryTab.albums,
            activeTab: library.tab,
          ),
          _LibraryRow(
            icon: Icons.grid_view_rounded,
            label: l10n.genres,
            tab: LibraryTab.genres,
            activeTab: library.tab,
          ),
          _LibraryRow(
            icon: Icons.queue_music_rounded,
            label: l10n.allPlaylists,
            tab: LibraryTab.playlists,
            activeTab: library.tab,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _SectionLabel(l10n.playlists.toUpperCase())),
              IconButton(
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.add),
                color: petal.colors.ink2,
                tooltip: 'New playlist',
                onPressed: () => _createPlaylist(context, ref),
              ),
            ],
          ),
          playlistsAsync.when(
            data: (playlists) => Column(
              children: playlists
                  .map((p) => _RailAction(
                        icon: Icons.queue_music,
                        label: p.name,
                        onTap: () {
                          ref.read(currentSectionProvider.notifier).state = AppSection.library;
                          ref.read(libraryControllerProvider.notifier).filterByPlaylist(p.id, p.name);
                        },
                      ))
                  .toList(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),
          _SectionLabel(l10n.sources.toUpperCase()),
          _SourceRow(icon: Icons.phone_android_rounded, label: l10n.thisDevice, connected: localConnected, locked: kIsWeb),
          _SourceRow(icon: Icons.cloud_outlined, label: 'Google Drive', connected: driveConnected, locked: false),
          _SourceRow(icon: Icons.cloud_queue, label: 'OneDrive', connected: oneDriveConnected, locked: false),
          _RailAction(
            icon: Icons.add,
            label: l10n.addSource,
            onTap: () => ref.read(currentSectionProvider.notifier).state = AppSection.addSource,
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    String? artworkData;
    final draft = await showDialog<_PlaylistDraft>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New playlist'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      withData: true,
                    );
                    final bytes = result?.files.single.bytes;
                    if (bytes != null && bytes.length <= 5 * 1024 * 1024) {
                      setDialogState(() => artworkData = base64Encode(bytes));
                    }
                  },
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: artworkData == null
                        ? const Icon(Icons.add_photo_alternate_outlined, size: 38)
                        : Image.memory(base64Decode(artworkData!), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Playlist name'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                _PlaylistDraft(controller.text, artworkData),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (draft != null && draft.name.trim().isNotEmpty) {
      await ref.read(libraryControllerProvider.notifier).createPlaylist(
            draft.name.trim(),
            artworkData: draft.artworkData,
          );
    }
  }
}

class _PlaylistDraft {
  final String name;
  final String? artworkData;
  const _PlaylistDraft(this.name, this.artworkData);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Text(text, style: petal.text.settingsGroupTitle),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool connected;
  final bool locked;
  const _SourceRow({required this.icon, required this.label, required this.connected, required this.locked});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 17, color: petal.colors.ink2),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: petal.text.trackSubtitle.copyWith(fontSize: 13, color: petal.colors.ink))),
          if (locked)
            Icon(Icons.lock_outline, size: 13, color: petal.colors.ink3)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? petal.colors.good : petal.colors.ink3,
              ),
            ),
        ],
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  const _RailAction({required this.icon, required this.label, required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Material(
      color: selected ? petal.colors.surface2 : Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? petal.colors.accent : petal.colors.ink2),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label, overflow: TextOverflow.ellipsis, style: petal.text.trackSubtitle.copyWith(color: petal.colors.ink, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryRow extends ConsumerWidget {
  final IconData icon;
  final String label;
  final LibraryTab tab;
  final LibraryTab activeTab;

  const _LibraryRow({
    required this.icon,
    required this.label,
    required this.tab,
    required this.activeTab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _RailAction(
      icon: icon,
      label: label,
      selected: tab == activeTab &&
          !ref.watch(libraryControllerProvider).filter.isActive,
      onTap: () {
        ref.read(currentSectionProvider.notifier).state = AppSection.library;
        ref.read(libraryControllerProvider.notifier).setTab(tab);
      },
    );
  }
}
