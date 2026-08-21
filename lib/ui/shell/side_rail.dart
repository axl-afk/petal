import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/auth_session.dart';
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
    final session = ref.watch(authControllerProvider).session;
    final playlistsAsync = ref.watch(playlistsStreamProvider);

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
          _SectionLabel('SOURCES'),
          _SourceRow(icon: Icons.laptop_mac, label: 'Local files', connected: localConnected, locked: kIsWeb),
          _SourceRow(icon: Icons.cloud_outlined, label: 'Google Drive', connected: driveConnected, locked: false),
          _SourceRow(icon: Icons.cloud_queue, label: 'OneDrive', connected: oneDriveConnected, locked: false),
          _RailAction(
            icon: Icons.add,
            label: 'Add a source',
            onTap: () => ref.read(currentSectionProvider.notifier).state = AppSection.addSource,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _SectionLabel('PLAYLISTS')),
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
          const SizedBox(height: 22),
          _RailAction(
            icon: Icons.favorite_border,
            label: 'Favorites',
            onTap: () {
              ref.read(currentSectionProvider.notifier).state = AppSection.library;
              ref.read(libraryControllerProvider.notifier).setTab(LibraryTab.favorites);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Playlist name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(libraryControllerProvider.notifier).createPlaylist(name.trim());
    }
  }
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
  const _RailAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: petal.colors.ink2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, overflow: TextOverflow.ellipsis, style: petal.text.trackSubtitle.copyWith(color: petal.colors.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
