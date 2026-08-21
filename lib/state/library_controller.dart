import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/db/daos/playlist_dao.dart';
import '../data/db/daos/source_dao.dart';
import '../data/db/daos/track_dao.dart';
import '../data/db/tables.dart';
import '../data/models/resolved_source.dart';
import '../data/services/link_resolver_service.dart';
import '../data/services/local_file_service.dart';
import '../utils/id_gen.dart';
import 'providers.dart';

enum LibraryTab { songs, artists, genres, playlists, favorites }

class LibraryFilter {
  final String? artist;
  final String? genre;
  final String? playlistId;
  final String? playlistName;

  const LibraryFilter({this.artist, this.genre, this.playlistId, this.playlistName});
  static const none = LibraryFilter();

  bool get isActive => artist != null || genre != null || playlistId != null;
}

class LibraryState {
  final LibraryTab tab;
  final LibraryFilter filter;
  final String searchQuery;

  const LibraryState({
    this.tab = LibraryTab.songs,
    this.filter = LibraryFilter.none,
    this.searchQuery = '',
  });

  LibraryState copyWith({LibraryTab? tab, LibraryFilter? filter, String? searchQuery}) => LibraryState(
        tab: tab ?? this.tab,
        filter: filter ?? this.filter,
        searchQuery: searchQuery ?? this.searchQuery,
      );

  bool get isSearching => searchQuery.trim().isNotEmpty;
}

class LibraryController extends StateNotifier<LibraryState> {
  final TrackDao trackDao;
  final PlaylistDao playlistDao;
  final SourceDao sourceDao;
  final LinkResolverService resolver;
  final LocalFileService localFiles;

  LibraryController(this.trackDao, this.playlistDao, this.sourceDao, this.resolver, this.localFiles)
      : super(const LibraryState());

  // --- navigation / filtering -------------------------------------------

  void setTab(LibraryTab tab) => state = state.copyWith(tab: tab, filter: LibraryFilter.none, searchQuery: '');

  void filterByArtist(String artist) =>
      state = state.copyWith(tab: LibraryTab.songs, filter: LibraryFilter(artist: artist));

  void filterByGenre(String genre) =>
      state = state.copyWith(tab: LibraryTab.songs, filter: LibraryFilter(genre: genre));

  void filterByPlaylist(String id, String name) => state = state.copyWith(
        tab: LibraryTab.songs,
        filter: LibraryFilter(playlistId: id, playlistName: name),
      );

  void clearFilter() => state = state.copyWith(filter: LibraryFilter.none);

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  /// The stream the Library screen's track table subscribes to — resolves
  /// tab/filter/search into the right DAO query, so the UI never needs to
  /// know about drift directly.
  Stream<List<Track>> currentTracksStream() {
    if (state.isSearching) {
      return trackDao.search(state.searchQuery).asStream();
    }
    if (state.filter.playlistId != null) return playlistDao.watchTracks(state.filter.playlistId!);
    if (state.filter.artist != null) return trackDao.watchByArtist(state.filter.artist!);
    if (state.filter.genre != null) return trackDao.watchByGenre(state.filter.genre!);
    if (state.tab == LibraryTab.favorites) return trackDao.watchFavorites();
    return trackDao.watchAll();
  }

  // --- mutations ----------------------------------------------------------

  Future<void> toggleFavorite(Track track) => trackDao.setFavorite(track.id, !track.isFavorite);

  Future<void> importLocalFiles() async {
    if (kIsWeb) {
      throw StateError('The web version of Petal doesn\'t have access to local files — use the installed app.');
    }
    final picked = await localFiles.pickAudioFiles();
    if (picked.isEmpty) return;
    final companions = picked
        .map((f) => TracksCompanion.insert(
              id: newId(),
              title: localFiles.titleFromFileName(f.fileName),
              sourceType: TrackSourceType.local,
              sourceUri: f.path,
              originUri: f.path,
            ))
        .toList();
    await trackDao.upsertAll(companions);
  }

  /// Resolves a pasted Drive/OneDrive/direct link and, on success, adds it
  /// as a track. Returns the resolution result so the Add Source screen can
  /// show a clear error inline instead of failing silently.
  Future<ResolvedSource> connectLink({
    required String rawLink,
    required String title,
    String artist = 'Unknown Artist',
    String? accountEmail,
  }) async {
    final resolved = resolver.resolve(rawLink);
    if (!resolved.ok || resolved.playableUri == null) return resolved;

    final sourceType = switch (resolved.provider) {
      LinkProviderKind.googleDrive => TrackSourceType.googleDrive,
      LinkProviderKind.oneDrive => TrackSourceType.oneDrive,
      _ => TrackSourceType.direct,
    };

    await trackDao.upsert(TracksCompanion.insert(
      id: newId(),
      title: title.trim().isEmpty ? 'Untitled Track' : title.trim(),
      artist: Value(artist),
      sourceType: sourceType,
      sourceUri: resolved.playableUri!,
      originUri: rawLink,
      ownerAccount: Value(accountEmail),
    ));

    if (accountEmail != null && sourceType != TrackSourceType.direct) {
      await sourceDao.add(
        provider: sourceType,
        rawLink: rawLink,
        accountEmail: accountEmail,
        label: title,
      );
    }

    return resolved;
  }

  /// Runs right after sign-in: re-resolves every link this account has
  /// saved before, so switching devices (or reinstalling) brings the cloud
  /// library back without the user re-pasting anything.
  Future<void> reconnectSavedSourcesForAccount(String accountEmail) async {
    final saved = await sourceDao.getForAccount(accountEmail);
    for (final source in saved) {
      final resolved = resolver.resolve(source.rawLink);
      if (!resolved.ok || resolved.playableUri == null) continue;
      await trackDao.upsert(TracksCompanion.insert(
        id: newId(),
        title: source.label ?? 'Untitled Track',
        sourceType: source.provider,
        sourceUri: resolved.playableUri!,
        originUri: source.rawLink,
        ownerAccount: Value(accountEmail),
      ));
    }
  }

  Future<Playlist> createPlaylist(String name) => playlistDao.create(name);

  Future<void> addTrackToPlaylist(String playlistId, String trackId) =>
      playlistDao.addTrack(playlistId, trackId);
}

final libraryControllerProvider = StateNotifierProvider<LibraryController, LibraryState>((ref) {
  return LibraryController(
    ref.watch(trackDaoProvider),
    ref.watch(playlistDaoProvider),
    ref.watch(sourceDaoProvider),
    ref.watch(linkResolverServiceProvider),
    ref.watch(localFileServiceProvider),
  );
});

final artistsStreamProvider = StreamProvider<List<ArtistSummary>>((ref) {
  return ref.watch(trackDaoProvider).watchArtists();
});

final genresStreamProvider = StreamProvider<List<GenreSummary>>((ref) {
  return ref.watch(trackDaoProvider).watchGenres();
});

final playlistsStreamProvider = StreamProvider<List<Playlist>>((ref) {
  return ref.watch(playlistDaoProvider).watchAll();
});

final currentTracksStreamProvider = StreamProvider.autoDispose<List<Track>>((ref) {
  ref.watch(libraryControllerProvider); // rebuild when tab/filter/search changes
  return ref.watch(libraryControllerProvider.notifier).currentTracksStream();
});
