import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/db/daos/playlist_dao.dart';
import '../data/db/daos/source_dao.dart';
import '../data/db/daos/track_dao.dart';
import '../data/db/tables.dart';
import '../data/models/auth_session.dart' show AuthProviderKind;
import '../data/models/resolved_source.dart';
import '../data/services/link_resolver_service.dart';
import '../data/services/local_file_service.dart';
import '../utils/id_gen.dart';
import 'auth_controller.dart';
import 'cloud_sync_controller.dart';
import 'providers.dart';

/// Result of a local import batch — how many files were found vs. actually
/// added, so the UI can say something more useful than a generic "done".
class ImportResult {
  final int found;
  final int imported;
  const ImportResult({required this.found, required this.imported});
}

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
  final Ref _ref;

  LibraryController(this.trackDao, this.playlistDao, this.sourceDao, this.resolver, this.localFiles, this._ref)
      : super(const LibraryState());

  /// Kicks a debounced Google Drive backup (see cloud_sync_controller.dart)
  /// after any mutation that a signed-in Google account cares about
  /// carrying to other devices. No-ops for a signed-out user, a
  /// Microsoft-signed-in user (no Drive backup for OneDrive accounts yet),
  /// or a purely local-file change (those never sync — see
  /// library_sync_service.dart).
  void _scheduleBackupIfGoogle() {
    final auth = _ref.read(authControllerProvider);
    final session = auth.session;
    if (session != null && session.provider == AuthProviderKind.google) {
      _ref.read(cloudSyncControllerProvider.notifier).scheduleBackup(session.email);
    }
  }

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

  Future<void> toggleFavorite(Track track) async {
    await trackDao.setFavorite(track.id, !track.isFavorite);
    // Only cloud-sourced tracks (ids from idForCloudSource, see
    // connectLink) are part of what gets backed up — skip scheduling a
    // Drive write for a purely local-file favorite, which buildSnapshot()
    // would just filter out anyway.
    if (track.id.startsWith('cloud_')) _scheduleBackupIfGoogle();
  }

  Future<ImportResult> importLocalFiles() async {
    if (kIsWeb) {
      throw StateError('The web version of Petal doesn\'t have access to local files — use the installed app.');
    }
    final picked = await localFiles.pickAudioFiles();
    return _importPaths(picked);
  }

  /// Pick a folder and recursively import every audio file found under it
  /// (including subfolders) — the "point at a folder, not one file at a
  /// time" import most desktop music players offer.
  Future<ImportResult?> importFolder() async {
    if (kIsWeb) {
      throw StateError('The web version of Petal doesn\'t have access to local files — use the installed app.');
    }
    final folder = await localFiles.pickAudioFolder();
    if (folder == null) return null; // user cancelled the folder picker
    final paths = await localFiles.scanFolderForAudio(folder);
    return _importPaths(paths);
  }

  /// Quick-scan the OS's known Music folder (desktop only — see
  /// LocalFileService.platformMusicFolder for why this, not a literal
  /// whole-disk crawl, is what "auto scan for music" means here). Returns
  /// null if there's no such folder on this platform/machine.
  Future<ImportResult?> scanPlatformMusicFolder() async {
    if (kIsWeb) return null;
    final folder = await localFiles.platformMusicFolder();
    if (folder == null) return null;
    final paths = await localFiles.scanFolderForAudio(folder);
    return _importPaths(paths);
  }

  Future<ImportResult> _importPaths(List<String> paths) async {
    if (paths.isEmpty) return const ImportResult(found: 0, imported: 0);

    final companions = <TracksCompanion>[];
    for (final path in paths) {
      try {
        final imported = await localFiles.importFile(path);
        companions.add(TracksCompanion.insert(
          id: imported.id,
          title: imported.title,
          artist: Value(imported.artist),
          album: Value(imported.album),
          genre: Value(imported.genre),
          durationMs: Value(imported.durationMs),
          sourceType: TrackSourceType.local,
          sourceUri: imported.storedPath,
          originUri: path,
          artworkUrl: Value(imported.artworkPath),
        ));
      } catch (_) {
        // One bad file (unreadable, disappeared mid-scan, disk full on the
        // copy step) shouldn't abort the rest of the batch.
      }
    }
    if (companions.isNotEmpty) await trackDao.upsertAll(companions);
    return ImportResult(found: paths.length, imported: companions.length);
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

    // A deterministic id derived from the link itself (see idForCloudSource)
    // rather than a random one — otherwise pasting the same link twice, or
    // reconnecting it after sign-in, silently duplicated the track. It also
    // gives Google Drive backup a stable id to reference this track by from
    // another device (see library_sync_service.dart).
    await trackDao.upsert(TracksCompanion.insert(
      id: idForCloudSource(rawLink),
      title: title.trim().isEmpty ? 'Untitled Track' : title.trim(),
      artist: Value(artist),
      sourceType: sourceType,
      sourceUri: resolved.playableUri!,
      originUri: rawLink,
      ownerAccount: Value(accountEmail),
    ));

    if (accountEmail != null && sourceType != TrackSourceType.direct) {
      await sourceDao.upsertForAccount(
        accountEmail: accountEmail,
        provider: sourceType,
        rawLink: rawLink,
        label: title,
      );
      _scheduleBackupIfGoogle();
    }

    return resolved;
  }

  /// Runs right after Microsoft sign-in (Google uses the Drive-backup path
  /// in cloud_sync_controller.dart instead — see AuthController.signIn):
  /// re-resolves every link this account has saved on this device before,
  /// so switching devices (or reinstalling) brings the cloud library back
  /// without the user re-pasting anything, as long as this exact device
  /// has seen those links before.
  Future<void> reconnectSavedSourcesForAccount(String accountEmail) async {
    final saved = await sourceDao.getForAccount(accountEmail);
    for (final source in saved) {
      final resolved = resolver.resolve(source.rawLink);
      if (!resolved.ok || resolved.playableUri == null) continue;
      await trackDao.upsert(TracksCompanion.insert(
        id: idForCloudSource(source.rawLink),
        title: source.label ?? 'Untitled Track',
        sourceType: source.provider,
        sourceUri: resolved.playableUri!,
        originUri: source.rawLink,
        ownerAccount: Value(accountEmail),
      ));
    }
  }

  // Not itself hooked to _scheduleBackupIfGoogle — a brand-new playlist has
  // no tracks yet, and buildSnapshot() skips any playlist with no
  // cloud-portable tracks in it, so there'd be nothing new to back up until
  // addTrackToPlaylist (below) actually adds one.
  Future<Playlist> createPlaylist(String name) => playlistDao.create(name);

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    await playlistDao.addTrack(playlistId, trackId);
    // Same reasoning as toggleFavorite above — a playlist full of purely
    // local tracks has nothing cloud-portable in it (buildSnapshot() skips
    // playlists with no cloud track ids), so only bother syncing when this
    // addition could actually change what gets backed up.
    if (trackId.startsWith('cloud_')) _scheduleBackupIfGoogle();
  }
}

final libraryControllerProvider = StateNotifierProvider<LibraryController, LibraryState>((ref) {
  return LibraryController(
    ref.watch(trackDaoProvider),
    ref.watch(playlistDaoProvider),
    ref.watch(sourceDaoProvider),
    ref.watch(linkResolverServiceProvider),
    ref.watch(localFileServiceProvider),
    ref,
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
