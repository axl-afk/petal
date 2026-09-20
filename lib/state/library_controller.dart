import 'dart:async' show Timer;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/db/daos/playlist_dao.dart';
import '../data/db/daos/source_dao.dart';
import '../data/db/daos/track_dao.dart';
import '../data/db/tables.dart';
import '../data/models/auth_session.dart' show AuthProviderKind;
import '../data/models/cloud_audio_item.dart';
import '../data/models/resolved_source.dart';
import '../data/services/auth/google_auth_service.dart';
import '../data/services/auth/microsoft_auth_service.dart';
import '../data/services/cloud_library_service.dart';
import '../data/services/drive_folder_service.dart';
import '../data/services/device_media_service.dart';
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

  const LibraryFilter({
    this.artist,
    this.genre,
    this.playlistId,
    this.playlistName,
  });
  static const none = LibraryFilter();

  bool get isActive => artist != null || genre != null || playlistId != null;
}

class LibraryState {
  final LibraryTab tab;
  final LibraryFilter filter;
  final String searchQuery;
  final bool cloudScanBusy;
  final int cloudScanDiscovered;
  final String? cloudScanError;
  final DateTime? lastCloudScanAt;

  const LibraryState({
    this.tab = LibraryTab.songs,
    this.filter = LibraryFilter.none,
    this.searchQuery = '',
    this.cloudScanBusy = false,
    this.cloudScanDiscovered = 0,
    this.cloudScanError,
    this.lastCloudScanAt,
  });

  LibraryState copyWith({
    LibraryTab? tab,
    LibraryFilter? filter,
    String? searchQuery,
    bool? cloudScanBusy,
    int? cloudScanDiscovered,
    String? cloudScanError,
    bool clearCloudScanError = false,
    DateTime? lastCloudScanAt,
  }) => LibraryState(
    tab: tab ?? this.tab,
    filter: filter ?? this.filter,
    searchQuery: searchQuery ?? this.searchQuery,
    cloudScanBusy: cloudScanBusy ?? this.cloudScanBusy,
    cloudScanDiscovered: cloudScanDiscovered ?? this.cloudScanDiscovered,
    cloudScanError: clearCloudScanError
        ? null
        : (cloudScanError ?? this.cloudScanError),
    lastCloudScanAt: lastCloudScanAt ?? this.lastCloudScanAt,
  );

  bool get isSearching => searchQuery.trim().isNotEmpty;
}

class LibraryController extends StateNotifier<LibraryState> {
  final TrackDao trackDao;
  final PlaylistDao playlistDao;
  final SourceDao sourceDao;
  final LinkResolverService resolver;
  final LocalFileService localFiles;
  final DeviceMediaService deviceMedia;
  final GoogleAuthService googleAuth;
  final MicrosoftAuthService microsoftAuth;
  final DriveFolderService driveFolder;
  final CloudLibraryService cloudLibrary;
  final Ref _ref;

  // Search-quality review finding: every keystroke in the search box used
  // to re-run the DB query immediately — on a large library this meant a
  // full FTS/LIKE query (plus a rebuild and, per the loading-flicker note
  // on currentTracksStreamProvider's consumer, a visible spinner) for every
  // single character typed. Debouncing here (rather than in the TextField
  // itself) means the typed text always appears instantly — the field in
  // top_bar.dart isn't hooked to a controller reflecting this state, it's
  // plain Flutter-managed text — while the actual query only runs once
  // typing pauses.
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  LibraryController(
    this.trackDao,
    this.playlistDao,
    this.sourceDao,
    this.resolver,
    this.localFiles,
    this.deviceMedia,
    this.googleAuth,
    this.microsoftAuth,
    this.driveFolder,
    this.cloudLibrary,
    this._ref,
  ) : super(const LibraryState());

  /// Kicks a debounced Google Drive backup (see cloud_sync_controller.dart)
  /// after any mutation that a signed-in Google account cares about
  /// carrying to other devices. No-ops for a signed-out user, a
  /// Microsoft-signed-in user (no Drive backup for OneDrive accounts yet),
  /// or a purely local-file change (those never sync — see
  /// library_sync_service.dart).
  void _schedulePortableBackup() {
    final auth = _ref.read(authControllerProvider);
    final session = auth.session;
    if (session != null) {
      _ref.read(cloudSyncControllerProvider.notifier).scheduleBackup(session);
    }
  }

  // --- navigation / filtering -------------------------------------------

  void setTab(LibraryTab tab) {
    _searchDebounce?.cancel();
    state = state.copyWith(
      tab: tab,
      filter: LibraryFilter.none,
      searchQuery: '',
    );
  }

  void filterByArtist(String artist) {
    _searchDebounce?.cancel();
    state = state.copyWith(
      tab: LibraryTab.songs,
      filter: LibraryFilter(artist: artist),
    );
  }

  void filterByGenre(String genre) {
    _searchDebounce?.cancel();
    state = state.copyWith(
      tab: LibraryTab.songs,
      filter: LibraryFilter(genre: genre),
    );
  }

  void filterByPlaylist(String id, String name) {
    _searchDebounce?.cancel();
    state = state.copyWith(
      tab: LibraryTab.songs,
      filter: LibraryFilter(playlistId: id, playlistName: name),
    );
  }

  void clearFilter() {
    _searchDebounce?.cancel();
    state = state.copyWith(filter: LibraryFilter.none);
  }

  /// Debounced: the query only actually reaches [state] (and therefore
  /// re-runs the DB search — see currentTracksStream) 300ms after typing
  /// pauses, not on every keystroke. setTab/clearFilter/filterBy* above each
  /// cancel any pending timer from this method, so a stale debounced search
  /// can never overwrite a filter or tab switch made while it was waiting.
  void setSearchQuery(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      state = state.copyWith(searchQuery: query);
    });
  }

  /// The stream the Library screen's track table subscribes to — resolves
  /// tab/filter/search into the right DAO query, so the UI never needs to
  /// know about drift directly.
  Stream<List<Track>> currentTracksStream() {
    if (state.isSearching) {
      // trackDao.search() is already a reactive Stream (see track_dao.dart)
      // — it used to be a one-shot Future wrapped in .asStream(), which is
      // why search results never live-updated while search was active.
      return trackDao.search(state.searchQuery);
    }
    if (state.filter.playlistId != null)
      return playlistDao.watchTracks(state.filter.playlistId!);
    if (state.filter.artist != null)
      return trackDao.watchByArtist(state.filter.artist!);
    if (state.filter.genre != null)
      return trackDao.watchByGenre(state.filter.genre!);
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
    if (track.id.startsWith('cloud_')) _schedulePortableBackup();
  }

  Future<ImportResult> importLocalFiles() async {
    if (kIsWeb) {
      throw StateError(
        'The web version of Petal doesn\'t have access to local files — use the installed app.',
      );
    }
    final picked = await localFiles.pickAudioFiles();
    return _importPaths(picked);
  }

  /// Pick a folder and recursively import every audio file found under it
  /// (including subfolders) — the "point at a folder, not one file at a
  /// time" import most desktop music players offer.
  Future<ImportResult?> importFolder() async {
    if (kIsWeb) {
      throw StateError(
        'The web version of Petal doesn\'t have access to local files — use the installed app.',
      );
    }
    final folder = await localFiles.pickAudioFolder();
    if (folder == null) return null; // user cancelled the folder picker
    final paths = await localFiles.scanFolderForAudio(folder);
    return _importPaths(paths);
  }

  /// Quick-scan the OS's known Music folder (desktop only) — the fast,
  /// common-case option. Returns null if there's no such folder on this
  /// platform/machine. For an actual whole-disk crawl, see
  /// scanWholeComputer below.
  Future<ImportResult?> scanPlatformMusicFolder() async {
    if (kIsWeb) return null;
    final folder = await localFiles.platformMusicFolder();
    if (folder == null) return null;
    final paths = await localFiles.scanFolderForAudio(folder);
    return _importPaths(paths);
  }

  /// Queries Android's indexed MediaStore library. This is the supported
  /// phone equivalent of a filesystem scan and returns stable content URIs.
  /// iOS uses importLocalFiles because iOS does not expose a global library
  /// scan API to third-party apps.
  Future<ImportResult?> scanDeviceMusic() async {
    if (!deviceMedia.supported) return null;
    final items = await deviceMedia.scanAudio();
    final rows = items
        .map(
          (item) => TracksCompanion.insert(
            id: idForLocalPath(item.contentUri),
            title: item.title,
            artist: Value(item.artist),
            album: Value(item.album),
            durationMs: Value(item.durationMs),
            sourceType: TrackSourceType.local,
            sourceUri: item.contentUri,
            originUri: item.contentUri,
          ),
        )
        .toList();
    if (rows.isNotEmpty) await trackDao.upsertAll(rows);
    return ImportResult(found: items.length, imported: rows.length);
  }

  /// A real, literal whole-computer scan — every user-accessible drive/
  /// volume the OS exposes, not just the Music folder. Desktop only: on
  /// Android/iOS this isn't a filesystem-crawl problem at all — most audio
  /// files live behind MediaStore (Android) or the Photos-library-style
  /// picker (iOS), not a plain accessible path the way desktop files are,
  /// so a "scan the whole phone" feature needs a real platform-integration
  /// package (e.g. on_audio_query on Android) rather than this method —
  /// deliberately not attempted here without verifying that package's
  /// actual API first, the same lesson this app's audiotags/CI failures
  /// already taught the hard way (see README's "Known limitations"). Slower
  /// than the Music-folder scan by nature (it's walking far more of the
  /// disk) — [onProgress], if given, is called with a running found-count
  /// so the UI can show live progress instead of an indefinite spinner.
  Future<ImportResult?> scanWholeComputer({
    void Function(int foundSoFar)? onProgress,
  }) async {
    if (kIsWeb) return null;
    final paths = await localFiles.scanWholeComputer(onProgress: onProgress);
    return _importPaths(paths);
  }

  Future<ImportResult> _importPaths(List<String> paths) async {
    if (paths.isEmpty) return const ImportResult(found: 0, imported: 0);

    final companions = <TracksCompanion>[];
    for (final path in paths) {
      try {
        final imported = await localFiles.importFile(path);
        companions.add(
          TracksCompanion.insert(
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
          ),
        );
      } catch (_) {
        // One bad file (unreadable, disappeared mid-scan, disk full on the
        // copy step) shouldn't abort the rest of the batch.
      }
    }
    if (companions.isNotEmpty) await trackDao.upsertAll(companions);
    return ImportResult(found: paths.length, imported: companions.length);
  }

  /// Scans the connected provider account and merges every supported audio
  /// item into the unified library. Provider item IDs make repeat scans
  /// idempotent; user state such as favorites and lyrics survives refreshes.
  Future<ImportResult> scanConnectedCloud() async {
    final session = _ref.read(authControllerProvider).session;
    if (session == null)
      throw StateError('Sign in with Google or Microsoft first.');

    state = state.copyWith(
      cloudScanBusy: true,
      cloudScanDiscovered: 0,
      clearCloudScanError: true,
    );
    try {
      final onProgress = (int count) {
        state = state.copyWith(cloudScanDiscovered: count);
      };
      final items = switch (session.provider) {
        AuthProviderKind.google => await _scanGoogle(onProgress),
        AuthProviderKind.microsoft => await _scanMicrosoft(onProgress),
      };

      final rows = items
          .map(
            (item) => TracksCompanion.insert(
              id: idForCloudSource(item.stableOrigin),
              title: item.title.isEmpty ? 'Untitled Track' : item.title,
              sourceType: item.provider,
              sourceUri: item.streamUri,
              originUri: item.stableOrigin,
              ownerAccount: Value(session.email),
              providerItemId: Value(item.providerItemId),
              mimeType: Value(item.mimeType),
              fileSizeBytes: Value(item.sizeBytes ?? 0),
              remoteModifiedAt: Value(item.modifiedAt),
              artworkUrl: Value(item.artworkUrl),
            ),
          )
          .toList();
      if (rows.isNotEmpty) await trackDao.upsertAll(rows);
      _schedulePortableBackup();
      state = state.copyWith(
        cloudScanBusy: false,
        cloudScanDiscovered: items.length,
        lastCloudScanAt: DateTime.now(),
        clearCloudScanError: true,
      );
      return ImportResult(found: items.length, imported: rows.length);
    } catch (error) {
      state = state.copyWith(
        cloudScanBusy: false,
        cloudScanError: error.toString(),
      );
      rethrow;
    }
  }

  Future<List<CloudAudioItem>> _scanGoogle(
    void Function(int) onProgress,
  ) async {
    final token = await googleAuth.refreshAccessToken();
    if (token == null) {
      throw StateError('Google access expired. Sign out and sign in again.');
    }
    return cloudLibrary.scanGoogleDrive(token, onProgress: onProgress);
  }

  Future<List<CloudAudioItem>> _scanMicrosoft(
    void Function(int) onProgress,
  ) async {
    final token = await microsoftAuth.accessToken();
    if (token == null) {
      throw StateError('Microsoft access expired. Sign out and sign in again.');
    }
    return cloudLibrary.scanOneDrive(token, onProgress: onProgress);
  }

  /// Resolves a pasted Drive/OneDrive/direct link and, on success, adds it
  /// as a track — or, for a Google Drive *folder* link, imports every
  /// audio file directly inside it (see _connectDriveFolder). Returns the
  /// resolution result so the Add Source screen can show a clear message
  /// inline instead of failing silently, for either shape of result
  /// (ResolvedSource.isFolderResult distinguishes them).
  Future<ResolvedSource> connectLink({
    required String rawLink,
    required String title,
    String artist = 'Unknown Artist',
    String? accountEmail,
  }) async {
    final folderId = resolver.driveFolderId(rawLink);
    if (folderId != null) {
      return _connectDriveFolder(
        folderId: folderId,
        accountEmail: accountEmail,
      );
    }

    final resolved = resolver.resolve(rawLink);
    if (!resolved.ok || resolved.playableUri == null) return resolved;

    final sourceType = switch (resolved.provider) {
      LinkProviderKind.googleDrive => TrackSourceType.googleDrive,
      LinkProviderKind.oneDrive => TrackSourceType.oneDrive,
      _ => TrackSourceType.direct,
    };

    // The "Untitled Track" bug fix: previously, an empty typed title always
    // fell straight to the generic fallback below — for a single Google
    // Drive file link, that's avoidable, since folder imports
    // (_connectDriveFolder below) already show the real Drive filename by
    // calling the Drive API for it. Do the same thing here when the user
    // left the title blank and is signed in: look up the file's actual
    // name instead of guessing. Best-effort — getFileName returns null on
    // any failure (not signed in, offline, Drive error) and this just
    // falls through to the plain "Untitled Track" fallback in that case,
    // same as before this fix existed.
    var resolvedTitle = title.trim();
    if (resolvedTitle.isEmpty &&
        sourceType == TrackSourceType.googleDrive &&
        accountEmail != null) {
      final fileId = resolver.driveFileId(rawLink);
      if (fileId != null) {
        final token = await googleAuth.refreshAccessToken();
        if (token != null) {
          final driveName = await driveFolder.getFileName(token, fileId);
          if (driveName != null && driveName.trim().isNotEmpty) {
            final dot = driveName.lastIndexOf('.');
            resolvedTitle = dot > 0
                ? driveName.substring(0, dot)
                : driveName.trim();
          }
        }
      }
    }
    final finalTitle = resolvedTitle.isEmpty ? 'Untitled Track' : resolvedTitle;

    // A deterministic id derived from the link itself (see idForCloudSource)
    // rather than a random one — otherwise pasting the same link twice, or
    // reconnecting it after sign-in, silently duplicated the track. It also
    // gives Google Drive backup a stable id to reference this track by from
    // another device (see library_sync_service.dart).
    await trackDao.upsert(
      TracksCompanion.insert(
        id: idForCloudSource(rawLink),
        title: finalTitle,
        artist: Value(artist),
        sourceType: sourceType,
        sourceUri: resolved.playableUri!,
        originUri: rawLink,
        ownerAccount: Value(accountEmail),
      ),
    );

    if (accountEmail != null && sourceType != TrackSourceType.direct) {
      await sourceDao.upsertForAccount(
        accountEmail: accountEmail,
        provider: sourceType,
        rawLink: rawLink,
        // finalTitle, not the original (possibly blank) title argument —
        // otherwise the real Drive-looked-up name above would show
        // immediately but get silently overwritten by "Untitled Track"
        // the next time this source resyncs from SavedSources (see
        // reconnectSavedSourcesForAccount and library_sync_service.dart's
        // applySnapshot, both of which read this label back later).
        label: finalTitle,
      );
      _schedulePortableBackup();
    }

    return resolved;
  }

  /// Imports every audio file directly inside a Google Drive folder (see
  /// LinkResolverService.driveFolderId for how a folder link is told apart
  /// from a single-file link). Unlike a single file, listing a folder's
  /// contents needs a real Drive API call — which needs a token, which
  /// needs the user signed in with Google — so this fails clearly if
  /// they're not, rather than silently doing nothing (the exact complaint
  /// that led here: a folder link used to just fall through to "make sure
  /// it's a single-file share link").
  Future<ResolvedSource> _connectDriveFolder({
    required String folderId,
    String? accountEmail,
  }) async {
    if (accountEmail == null) {
      return ResolvedSource.failure(
        "That's a folder link — importing a whole folder needs you signed in with Google "
        "first (Settings → Google), since listing what's inside it needs Drive access, not "
        "just a direct-download URL like a single file uses. A single-file link (Share → "
        "Copy link on one song) works either way.",
        provider: LinkProviderKind.googleDrive,
      );
    }

    final token = await googleAuth.refreshAccessToken();
    if (token == null) {
      return ResolvedSource.failure(
        'Could not get a Google Drive access token — try signing out and back in.',
        provider: LinkProviderKind.googleDrive,
      );
    }

    List<DriveFolderFile> files;
    try {
      files = await driveFolder.listAudioFiles(token, folderId);
    } catch (e) {
      return ResolvedSource.failure(
        e.toString(),
        provider: LinkProviderKind.googleDrive,
      );
    }

    if (files.isEmpty) {
      return ResolvedSource.failure(
        "Didn't find any audio files directly inside that folder (subfolders aren't scanned "
        "yet — move files up a level, or share the specific subfolder instead).",
        provider: LinkProviderKind.googleDrive,
      );
    }

    var imported = 0;
    for (final file in files) {
      final fileLink = 'https://drive.google.com/file/d/${file.id}/view';
      final resolvedFile = resolver.resolve(fileLink);
      if (!resolvedFile.ok || resolvedFile.playableUri == null) continue;

      final dot = file.name.lastIndexOf('.');
      final title = dot > 0 ? file.name.substring(0, dot) : file.name;

      await trackDao.upsert(
        TracksCompanion.insert(
          id: idForCloudSource(fileLink),
          title: title.trim().isEmpty ? 'Untitled Track' : title.trim(),
          sourceType: TrackSourceType.googleDrive,
          sourceUri: resolvedFile.playableUri!,
          originUri: fileLink,
          ownerAccount: Value(accountEmail),
        ),
      );
      await sourceDao.upsertForAccount(
        accountEmail: accountEmail,
        provider: TrackSourceType.googleDrive,
        rawLink: fileLink,
        label: title,
      );
      imported++;
    }

    if (imported > 0) _schedulePortableBackup();

    return ResolvedSource.folderSuccess(
      provider: LinkProviderKind.googleDrive,
      found: files.length,
      imported: imported,
    );
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
      await trackDao.upsert(
        TracksCompanion.insert(
          id: idForCloudSource(source.rawLink),
          title: source.label ?? 'Untitled Track',
          sourceType: source.provider,
          sourceUri: resolved.playableUri!,
          originUri: source.rawLink,
          ownerAccount: Value(accountEmail),
        ),
      );
    }
  }

  // Not itself hooked to _schedulePortableBackup — a brand-new playlist has
  // no tracks yet, and buildSnapshot() skips any playlist with no
  // cloud-portable tracks in it, so there'd be nothing new to back up until
  // addTrackToPlaylist (below) actually adds one.
  Future<Playlist> createPlaylist(String name) => playlistDao.create(name);

  /// Called on sign-out — see TrackDao.deleteForAccount's doc comment for
  /// why this is necessary (and safe) for a shared-device scenario.
  Future<void> clearAccountData(String accountEmail) =>
      trackDao.deleteForAccount(accountEmail);

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    await playlistDao.addTrack(playlistId, trackId);
    // Same reasoning as toggleFavorite above — a playlist full of purely
    // local tracks has nothing cloud-portable in it (buildSnapshot() skips
    // playlists with no cloud track ids), so only bother syncing when this
    // addition could actually change what gets backed up.
    if (trackId.startsWith('cloud_')) _schedulePortableBackup();
  }
}

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, LibraryState>((ref) {
      return LibraryController(
        ref.watch(trackDaoProvider),
        ref.watch(playlistDaoProvider),
        ref.watch(sourceDaoProvider),
        ref.watch(linkResolverServiceProvider),
        ref.watch(localFileServiceProvider),
        ref.watch(deviceMediaServiceProvider),
        ref.watch(googleAuthServiceProvider),
        ref.watch(microsoftAuthServiceProvider),
        ref.watch(driveFolderServiceProvider),
        ref.watch(cloudLibraryServiceProvider),
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

final currentTracksStreamProvider = StreamProvider.autoDispose<List<Track>>((
  ref,
) {
  ref.watch(
    libraryControllerProvider,
  ); // rebuild when tab/filter/search changes
  return ref.watch(libraryControllerProvider.notifier).currentTracksStream();
});
