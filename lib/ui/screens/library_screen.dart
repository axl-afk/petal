import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../state/library_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/playback_controller.dart';
import '../../state/providers.dart';
import '../../data/db/daos/track_dao.dart';
import '../../data/db/app_database.dart';
import '../../data/models/track_extensions.dart';
import '../../theme/app_theme.dart';
import '../widgets/grid_card.dart';
import '../widgets/track_art.dart';
import '../widgets/track_table.dart';

class LibraryScreen extends ConsumerWidget {
  final bool searchMode;
  const LibraryScreen({super.key, this.searchMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryControllerProvider);

    if (searchMode && !state.isSearching) {
      return const _SearchBrowse();
    }

    if (state.isSearching) {
      return _TrackListSection(
        eyebrow: 'Search your music',
        title: '"${state.searchQuery}"',
        subtitle: 'Songs from this device and your connected sources',
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

final _overviewTracksProvider = StreamProvider.autoDispose<List<Track>>(
  (ref) => ref.watch(trackDaoProvider).watchRecent(),
);

/// A real, personalized entry point built entirely from the indexed library.
/// Collections stay usable offline and never imply a streaming catalog.
class LibraryOverview extends ConsumerWidget {
  const LibraryOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petal = context.petal;
    final tracks = ref.watch(_overviewTracksProvider);
    final albums = ref.watch(albumsStreamProvider);
    final playlists = ref.watch(playlistsStreamProvider);

    void openTab(LibraryTab tab) {
      ref.read(libraryControllerProvider.notifier).setTab(tab);
      ref.read(currentSectionProvider.notifier).state = AppSection.library;
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 14),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR SPACE', style: petal.text.heroEyebrow),
                const SizedBox(height: 4),
                Text('Listen your way', style: petal.text.heroTitle),
                const SizedBox(height: 6),
                Text(
                  'Local and cloud music, together in one library.',
                  style: petal.text.heroSub,
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _OverviewShortcut(
                      icon: Icons.favorite_rounded,
                      title: 'Favorite songs',
                      onTap: () => openTab(LibraryTab.favorites),
                    ),
                    _OverviewShortcut(
                      icon: Icons.queue_music_rounded,
                      title: 'Playlists',
                      onTap: () => openTab(LibraryTab.playlists),
                    ),
                    _OverviewShortcut(
                      icon: Icons.album_rounded,
                      title: 'Albums',
                      onTap: () => openTab(LibraryTab.albums),
                    ),
                    _OverviewShortcut(
                      icon: Icons.music_note_rounded,
                      title: 'All songs',
                      onTap: () => openTab(LibraryTab.songs),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: albums.when(
            data: (items) => _OverviewShelf(
              title: 'Your albums',
              onSeeAll: () => openTab(LibraryTab.albums),
              count: items.length > 12 ? 12 : items.length,
              itemBuilder: (index) {
                final album = items[index];
                return GridCard(
                  icon: Icons.album_outlined,
                  title: album.album,
                  subtitle: album.artist,
                  onTap: () {
                    ref
                        .read(libraryControllerProvider.notifier)
                        .filterByAlbum(album.album);
                    ref.read(currentSectionProvider.notifier).state =
                        AppSection.library;
                  },
                );
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        SliverToBoxAdapter(
          child: playlists.when(
            data: (items) => _OverviewShelf(
              title: 'Playlists',
              onSeeAll: () => openTab(LibraryTab.playlists),
              count: items.length > 12 ? 12 : items.length,
              itemBuilder: (index) {
                final playlist = items[index];
                return GridCard(
                  icon: Icons.queue_music_rounded,
                  title: playlist.name,
                  subtitle: 'Your playlist',
                  imageBytes: playlist.artworkData == null
                      ? null
                      : base64Decode(playlist.artworkData!),
                  onTap: () {
                    ref
                        .read(libraryControllerProvider.notifier)
                        .filterByPlaylist(playlist.id, playlist.name);
                    ref.read(currentSectionProvider.notifier).state =
                        AppSection.library;
                  },
                );
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
          sliver: tracks.when(
            data: (items) => items.isEmpty
                ? SliverToBoxAdapter(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.library_music_outlined, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'Your music starts here',
                              style: petal.text.sectionTitle,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add files or connect a cloud source to see your music.',
                              textAlign: TextAlign.center,
                              style: petal.text.meta,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () =>
                                  ref
                                          .read(currentSectionProvider.notifier)
                                          .state =
                                      AppSection.addSource,
                              child: const Text('Add music'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Recently added',
                                  style: petal.text.sectionTitle,
                                ),
                              ),
                              TextButton(
                                onPressed: () => openTab(LibraryTab.songs),
                                child: const Text('See all'),
                              ),
                            ],
                          ),
                        );
                      }
                      final track = items[index - 1];
                      return ListTile(
                        key: ValueKey(track.id),
                        contentPadding: EdgeInsets.zero,
                        leading: TrackArt(track: track, size: 48),
                        title: Text(
                          track.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.displayArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: track.isFavorite
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                          icon: Icon(
                            track.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                          onPressed: () => ref
                              .read(libraryControllerProvider.notifier)
                              .toggleFavorite(track),
                        ),
                        onTap: () => ref
                            .read(playbackControllerProvider.notifier)
                            .playSingle(track, context: items),
                      );
                    }, childCount: items.length + 1),
                  ),
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) =>
                SliverToBoxAdapter(child: Text('Could not load music: $error')),
          ),
        ),
      ],
    );
  }
}

class _OverviewShortcut extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _OverviewShortcut({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 18, color: context.petal.colors.accent),
    label: Text(title),
    onPressed: onTap,
  );
}

class _OverviewShelf extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  final int count;
  final Widget Function(int) itemBuilder;
  const _OverviewShelf({
    required this.title,
    required this.onSeeAll,
    required this.count,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: context.petal.text.sectionTitle),
                ),
                TextButton(onPressed: onSeeAll, child: const Text('See all')),
              ],
            ),
          ),
          SizedBox(
            height: 186,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  SizedBox(width: 158, child: itemBuilder(index)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBrowse extends ConsumerWidget {
  const _SearchBrowse();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genres = ref.watch(genresStreamProvider);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SEARCH', style: context.petal.text.heroEyebrow),
                Text('Explore your music', style: context.petal.text.heroTitle),
                const SizedBox(height: 6),
                Text(
                  'Search the tracks you imported or connected.',
                  style: context.petal.text.heroSub,
                ),
                const SizedBox(height: 20),
                Text('Browse by genre', style: context.petal.text.sectionTitle),
              ],
            ),
          ),
        ),
        genres.when(
          data: (items) => items.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Your genres will appear after you add music.'),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.crossAxisExtent;
                      final columns = width < 520
                          ? 2
                          : width < 900
                          ? 3
                          : 4;
                      return SliverGrid.builder(
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.15,
                        ),
                        itemBuilder: (context, index) {
                          final genre = items[index];
                          return GridCard(
                            icon: Icons.graphic_eq_rounded,
                            title: genre.genre,
                            subtitle: '${genre.trackCount} songs',
                            onTap: () {
                              ref
                                  .read(libraryControllerProvider.notifier)
                                  .filterByGenre(genre.genre);
                              ref.read(currentSectionProvider.notifier).state =
                                  AppSection.library;
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
          loading: () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              SliverToBoxAdapter(child: Text('Could not load genres: $error')),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
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
              onBack: () =>
                  ref.read(libraryControllerProvider.notifier).clearFilter(),
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
