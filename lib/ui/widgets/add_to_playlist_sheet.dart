import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/models/track_extensions.dart';
import '../../state/library_controller.dart';
import '../../theme/app_theme.dart';
import 'glass_surface.dart';

/// Shared song action for lists and the full player. One song can belong to
/// multiple playlists; existing membership is handled by the DAO upsert.
class AddToPlaylistSheet extends ConsumerWidget {
  final Track track;
  const AddToPlaylistSheet({super.key, required this.track});

  static Future<void> show(BuildContext context, Track track) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddToPlaylistSheet(track: track),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsStreamProvider);
    final petal = context.petal;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.sizeOf(context).height * .72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add to playlist', style: petal.text.sectionTitle),
                const SizedBox(height: 4),
                Text(track.displayTitle, style: petal.text.meta),
                const SizedBox(height: 12),
                Flexible(
                  child: playlists.when(
                    data: (items) => ListView(
                      shrinkWrap: true,
                      children: [
                        for (final playlist in items)
                          ListTile(
                            leading: const Icon(Icons.queue_music_rounded),
                            title: Text(playlist.name),
                            onTap: () => _add(context, ref, playlist.id),
                          ),
                        ListTile(
                          leading: const Icon(Icons.add_rounded),
                          title: const Text('New playlist'),
                          onTap: () => _create(context, ref),
                        ),
                      ],
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        Text('Could not load playlists: $error'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, String id) async {
    await ref
        .read(libraryControllerProvider.notifier)
        .addTrackToPlaylist(id, track.id);
    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Added to playlist')),
      );
    }
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('New playlist'),
          content: TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Playlist name'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, name.text.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      if (result == null || result.isEmpty) return;
      final playlist = await ref
          .read(libraryControllerProvider.notifier)
          .createPlaylist(result);
      await ref
          .read(libraryControllerProvider.notifier)
          .addTrackToPlaylist(playlist.id, track.id);
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text('Added to $result')));
      }
    } finally {
      name.dispose();
    }
  }
}
