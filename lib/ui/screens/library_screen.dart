import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../../state/library_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/playback_controller.dart';
import '../../data/db/daos/track_dao.dart';
import '../../theme/app_theme.dart';
import '../widgets/grid_card.dart';
import '../widgets/track_table.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryControllerProvider);

    if (state.isSearching) {
      return _TrackListSection(
        eyebrow: 'Search',
        title: '"${state.searchQuery}"',
        subtitle: 'Results across your library',
      );
    }
    if (state.filter.artist != null) {
      return _TrackListSection(
        eyebrow: 'Artist',
        title: state.filter.artist!,
        subtitle: 'All songs by this artist',
        showBack: true,
      );
    }
    if (state.filter.album != null) {
      return _TrackListSection(
        eyebrow: 'Album',
        title: state.filter.album!,
        subtitle: 'Songs on this album',
        showBack: true,
      );
    }
    if (state.filter.genre != null) {
      return _TrackListSection(
        eyebrow: 'Genre',
        title: state.filter.genre!,
        subtitle: 'Songs in this genre',
        showBack: true,
      );
    }
    if (state.filter.playlistId != null) {
      return _TrackListSection(
        eyebrow: 'Playlist',
        title: state.filter.playlistName ?? 'Playlist',
        subtitle: 'Your playlist',
        showBack: true,
      );
    }

    switch (state.tab) {
      case LibraryTab.songs:
        return const _TrackListSection(
          eyebrow: 'Library',
          title: 'Your Music',
          subtitle: 'Everything you\'ve added',
        );
      case LibraryTab.favorites:
        return const _TrackListSection(
          eyebrow: 'Library',
          title: 'Favorites',
          subtitle: 'Songs you\'ve loved',
        );
      case LibraryTab.artists:
        return const _ArtistsGrid();
      case LibraryTab.albums:
        return const _AlbumsGrid();
      case LibraryTab.genres:
        return const _GenresGrid();
      case LibraryTab.playlists:
        return const _PlaylistsGrid();
    }
  }
}

class _TrackListSection extends ConsumerWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final bool showBack;

  const _TrackListSection({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(currentTracksStreamProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
          sliver: SliverToBoxAdapter(
            child: _LibraryHeading(
              eyebrow: eyebrow,
              title: title == 'Your Music' ? 'Songs' : title,
              subtitle: subtitle,
              showBack: showBack,
              onBack: () => ref
                  .read(libraryControllerProvider.notifier)
                  .clearFilter(),
              onPlay: () {
                final tracks = tracksAsync.value ?? const [];
                if (tracks.isNotEmpty) {
                  ref
                      .read(playbackControllerProvider.notifier)
                      .playQueue(tracks, 0);
                }
              },
              sortOrder: ref.watch(libraryControllerProvider).sortOrder,
              onSort: (order) => ref
                  .read(libraryControllerProvider.notifier)
                  .setSortOrder(order),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          // skipLoadingOnReload: search-quality review finding — tab/filter/
          // search changes all make currentTracksStreamProvider watch a new
          // underlying DB stream (a "reload", in Riverpod's terms, since it
          // depends on libraryControllerProvider via ref.watch). Without
          // this, .when() briefly replaces the already-visible track list
          // with a full-screen spinner on every one of those changes, even
          // though the new query is normally near-instant — a visible
          // flicker on literally every keystroke once search was made
          // reactive. With it, the previous list stays on screen (using the
          // AsyncValue's carried-over previous data) until the new query's
          // first result arrives, then swaps in place.
          sliver: tracksAsync.when(
            skipLoadingOnReload: true,
            data: (tracks) => TrackTable(tracks: tracks),
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('Couldn\'t load your library: $e'),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
      ],
    );
  }
}

class _LibraryHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onPlay;
  final TrackOrder sortOrder;
  final ValueChanged<TrackOrder> onSort;

  const _LibraryHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.showBack,
    required this.onBack,
    required this.onPlay,
    required this.sortOrder,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Row(
      children: [
        if (showBack) ...[
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow.toUpperCase(), style: petal.text.heroEyebrow),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: petal.text.heroTitle.copyWith(fontSize: 26),
              ),
              Text(subtitle, style: petal.text.heroSub),
            ],
          ),
        ),
        PopupMenuButton<TrackOrder>(
          tooltip: 'Sort songs',
          initialValue: sortOrder,
          onSelected: onSort,
          itemBuilder: (context) => TrackOrder.values
              .map(
                (order) => PopupMenuItem(
                  value: order,
                  child: Text(switch (order) {
                    TrackOrder.title => 'Title',
                    TrackOrder.artist => 'Artist',
                    TrackOrder.album => 'Album',
                    TrackOrder.recentlyAdded => 'Recently added',
                  }),
                ),
              )
              .toList(),
          icon: const Icon(Icons.sort_rounded),
        ),
        const SizedBox(width: 6),
        FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Play all'),
        ),
      ],
    );
  }
}

class _ArtistsGrid extends ConsumerWidget {
  const _ArtistsGrid();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petal = context.petal;
    final artistsAsync = ref.watch(artistsStreamProvider);
    return artistsAsync.when(
      data: (artists) => _Grid(
        itemCount: artists.length,
        itemBuilder: (context, i) {
          final a = artists[i];
          return GridCard(
            icon: Icons.person_outline,
            title: a.artist,
            subtitle: '${a.trackCount} song${a.trackCount == 1 ? '' : 's'}',
            onTap: () => ref
                .read(libraryControllerProvider.notifier)
                .filterByArtist(a.artist),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: petal.text.meta)),
    );
  }
}

class _GenresGrid extends ConsumerWidget {
  const _GenresGrid();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(genresStreamProvider);
    return genresAsync.when(
      data: (genres) => _Grid(
        itemCount: genres.length,
        itemBuilder: (context, i) {
          final g = genres[i];
          return GridCard(
            icon: Icons.grid_view_rounded,
            title: g.genre,
            subtitle: '${g.trackCount} song${g.trackCount == 1 ? '' : 's'}',
            onTap: () => ref
                .read(libraryControllerProvider.notifier)
                .filterByGenre(g.genre),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _AlbumsGrid extends ConsumerWidget {
  const _AlbumsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsStreamProvider);
    return albumsAsync.when(
      data: (albums) => _Grid(
        itemCount: albums.length,
        itemBuilder: (context, i) {
          final album = albums[i];
          return GridCard(
            icon: Icons.album_outlined,
            title: album.album,
            subtitle:
                '${album.artist} · ${album.trackCount} song${album.trackCount == 1 ? '' : 's'}',
            onTap: () => ref
                .read(libraryControllerProvider.notifier)
                .filterByAlbum(album.album),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _PlaylistsGrid extends ConsumerWidget {
  const _PlaylistsGrid();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    return playlistsAsync.when(
      data: (playlists) => _Grid(
        itemCount: playlists.length,
        itemBuilder: (context, i) {
          final p = playlists[i];
          return GridCard(
            icon: Icons.queue_music,
            title: p.name,
            subtitle: 'Playlist',
            imageBytes: p.artworkData == null
                ? null
                : base64Decode(p.artworkData!),
            onTap: () => ref
                .read(libraryControllerProvider.notifier)
                .filterByPlaylist(p.id, p.name),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

/// GridView.builder rather than GridView.count(children: [...]) — the
/// latter builds every card eagerly regardless of scroll position, which
/// stops being free once someone has a few hundred distinct artists.
/// builder only ever constructs the cards near the viewport.
class _Grid extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  const _Grid({required this.itemCount, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    if (itemCount == 0) {
      return Center(child: Text('Nothing here yet.', style: petal.text.meta));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520
            ? 2
            : constraints.maxWidth < 900
            ? 3
            : 4;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: columns == 2 ? 1.0 : 1.1,
            ),
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          ),
        );
      },
    );
  }
}
