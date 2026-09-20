import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'track_dao.g.dart';

class ArtistSummary {
  final String artist;
  final int trackCount;
  const ArtistSummary(this.artist, this.trackCount);
}

class GenreSummary {
  final String genre;
  final int trackCount;
  const GenreSummary(this.genre, this.trackCount);
}

class AlbumSummary {
  final String album;
  final String artist;
  final String? artworkUrl;
  final int trackCount;
  const AlbumSummary(this.album, this.artist, this.artworkUrl, this.trackCount);
}

enum TrackOrder { title, artist, album, recentlyAdded }

@DriftAccessor(tables: [Tracks])
class TrackDao extends DatabaseAccessor<AppDatabase> with _$TrackDaoMixin {
  TrackDao(super.db);

  Stream<List<Track>> watchAll({TrackOrder order = TrackOrder.title}) {
    final query = select(tracks);
    switch (order) {
      case TrackOrder.title:
        query.orderBy([(t) => OrderingTerm.asc(t.title)]);
        break;
      case TrackOrder.artist:
        query.orderBy([(t) => OrderingTerm.asc(t.artist)]);
        break;
      case TrackOrder.album:
        query.orderBy([(t) => OrderingTerm.asc(t.album)]);
        break;
      case TrackOrder.recentlyAdded:
        query.orderBy([(t) => OrderingTerm.desc(t.addedAt)]);
        break;
    }
    return query.watch();
  }

  Stream<List<Track>> watchByArtist(String artist) =>
      (select(tracks)
            ..where((t) => t.artist.equals(artist))
            ..orderBy([(t) => OrderingTerm.asc(t.title)]))
          .watch();

  Stream<List<Track>> watchByGenre(String genre) =>
      (select(tracks)
            ..where((t) => t.genre.equals(genre))
            ..orderBy([(t) => OrderingTerm.asc(t.title)]))
          .watch();

  Stream<List<Track>> watchByAlbum(String album) =>
      (select(tracks)
            ..where((t) => t.album.equals(album))
            ..orderBy([(t) => OrderingTerm.asc(t.title)]))
          .watch();

  Stream<List<Track>> watchFavorites() =>
      (select(tracks)
            ..where((t) => t.isFavorite.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.title)]))
          .watch();

  Future<Track?> getById(String id) =>
      (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Track>> getForAccount(String accountEmail) =>
      (select(tracks)..where((t) => t.ownerAccount.equals(accountEmail))).get();

  Stream<List<ArtistSummary>> watchArtists() {
    final count = tracks.id.count();
    final query = selectOnly(tracks)
      ..addColumns([tracks.artist, count])
      ..groupBy([tracks.artist])
      ..orderBy([OrderingTerm.asc(tracks.artist)]);
    return query.watch().map(
      (rows) => rows
          .map((r) => ArtistSummary(r.read(tracks.artist)!, r.read(count)!))
          .toList(),
    );
  }

  Stream<List<GenreSummary>> watchGenres() {
    final count = tracks.id.count();
    final query = selectOnly(tracks)
      ..addColumns([tracks.genre, count])
      ..where(tracks.genre.equals('').not())
      ..groupBy([tracks.genre])
      ..orderBy([OrderingTerm.asc(tracks.genre)]);
    return query.watch().map(
      (rows) => rows
          .map((r) => GenreSummary(r.read(tracks.genre)!, r.read(count)!))
          .toList(),
    );
  }

  Stream<List<AlbumSummary>> watchAlbums() {
    final count = tracks.id.count();
    final artist = tracks.artist.min();
    final artwork = tracks.artworkUrl.min();
    final query = selectOnly(tracks)
      ..addColumns([tracks.album, artist, artwork, count])
      ..where(tracks.album.equals('').not())
      ..groupBy([tracks.album])
      ..orderBy([OrderingTerm.asc(tracks.album)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => AlbumSummary(
              r.read(tracks.album)!,
              r.read(artist) ?? 'Unknown Artist',
              r.read(artwork),
              r.read(count)!,
            ),
          )
          .toList(),
    );
  }

  /// Full-text search over title/artist/album/genre using the tracks_fts
  /// FTS5 virtual table (see AppDatabase._createFts). Falls back to a plain
  /// LIKE scan if FTS5 isn't available for some reason (e.g. an older
  /// bundled sqlite3), so search never just breaks.
  ///
  /// Reactive (a `.watch()`-backed Stream), like every other list query in
  /// this DAO — found during a review that this used to be a plain
  /// one-shot Future wrapped in `.asStream()` (see LibraryController), so a
  /// favorite toggle, a re-import, or any other DB write made while search
  /// results were showing never refreshed them: the DB was correctly
  /// updated, the visible list just silently went stale. `customSelect`
  /// supports `.watch()` the same as a typed `select()` given a correct
  /// `readsFrom` (declared below), so this needed no uncertain API.
  Stream<List<Track>> search(String rawQuery) async* {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      yield* watchAll();
      return;
    }

    final ftsQuery = _toFtsPrefixQuery(query);
    final ftsStream = customSelect(
      'SELECT tracks.* FROM tracks_fts '
      'JOIN tracks ON tracks.rowid = tracks_fts.rowid '
      'WHERE tracks_fts MATCH ? '
      'ORDER BY rank',
      variables: [Variable.withString(ftsQuery)],
      readsFrom: {tracks},
    ).watch().map((rows) => rows.map((r) => tracks.map(r.data)).toList());

    try {
      yield* ftsStream;
    } catch (_) {
      // FTS5 itself threw (module unavailable — the doc comment's original
      // intent) — fall back to a reactive LIKE scan instead of losing
      // live-updates entirely on that path too.
      yield* _watchLikeSearch(query);
    }
  }

  /// The LIKE-based fallback path for [search], factored out so it can be
  /// reused if the FTS5 stream ever errors mid-stream, not just on its
  /// first emission. Escapes both SQL LIKE wildcards (`%` and `_`) out of
  /// the raw query — `%` was already stripped before this existed; `_`
  /// (LIKE's single-character wildcard) was found unescaped during review,
  /// which would make a query containing e.g. "foo_bar" also match
  /// "fooXbar".
  Stream<List<Track>> _watchLikeSearch(String query) {
    final like = '%${query.replaceAll('%', '').replaceAll('_', '')}%';
    return (select(tracks)
          ..where(
            (t) =>
                t.title.like(like) |
                t.artist.like(like) |
                t.album.like(like) |
                t.genre.like(like),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch();
  }

  /// Turns "wren st" into `"wren"* "st"*` — each whitespace-separated token
  /// becomes its own quoted FTS5 prefix match, mirroring how a user expects
  /// partial/incremental typing to behave.
  String _toFtsPrefixQuery(String input) {
    final tokens = input
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => t.replaceAll('"', ''))
        .map((t) => '"$t"*');
    return tokens.join(' ');
  }

  Future<void> upsert(TracksCompanion track) =>
      into(tracks).insertOnConflictUpdate(track);

  /// Inserts new tracks, or — for an id that already exists — updates only
  /// the fields a re-scan can legitimately refresh (title/artist/album/
  /// genre/duration/sourceUri/artworkUrl). Deliberately leaves isFavorite,
  /// cached lyrics, and addedAt alone on an existing row: this used to run
  /// as a raw `INSERT OR REPLACE`, which replaces the *entire* row —
  /// harmless back when every import got a random id (so this path never
  /// actually hit an existing row), but local-file imports now use a
  /// deterministic id derived from the file path specifically so re-scans
  /// update in place instead of duplicating (see utils/id_gen.dart). Once
  /// that's true, a blind full-row replace would silently un-favorite
  /// tracks and drop their cached lyrics every time a folder gets
  /// re-scanned — this does a plain select-then-insert-or-update instead,
  /// avoiding any uncertain-API batch/on-conflict helper.
  ///
  /// Runs as a single [transaction] — a review flagged the original version
  /// (a plain unwrapped loop of individual selects/inserts/updates) for two
  /// real problems on a big folder import: each row was its own separate
  /// disk commit (slow — hundreds/thousands of tiny transactions instead of
  /// one), and a crash or force-quit partway through a large batch could
  /// leave the library with only some of that scan's tracks saved, with no
  /// way to tell which. Wrapping the whole batch in one transaction fixes
  /// both: drift/sqlite batches the writes into a single commit, and if
  /// anything throws partway through, the whole batch rolls back instead of
  /// landing half-applied.
  Future<void> upsertAll(List<TracksCompanion> items) async {
    await transaction(() async {
      for (final item in items) {
        final id = item.id.value;
        final existing = await (select(
          tracks,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          await into(tracks).insert(item);
        } else {
          await (update(tracks)..where((t) => t.id.equals(id))).write(
            TracksCompanion(
              title: item.title,
              artist: item.artist,
              album: item.album,
              genre: item.genre,
              durationMs: item.durationMs,
              sourceUri: item.sourceUri,
              artworkUrl: item.artworkUrl,
              providerItemId: item.providerItemId,
              mimeType: item.mimeType,
              fileSizeBytes: item.fileSizeBytes,
              remoteModifiedAt: item.remoteModifiedAt,
            ),
          );
        }
      }
    });
  }

  Future<void> deleteById(String id) =>
      (delete(tracks)..where((t) => t.id.equals(id))).go();

  /// Removes every track this account added via a Drive/OneDrive/direct
  /// link — called on sign-out (see AuthController.signOut). Found during
  /// a security review: reads never filtered by ownerAccount, so on a
  /// shared device, whoever opened Petal next (signed out, or signed in as
  /// someone else) could still see and play everything the previous
  /// account had pasted. Safe to delete: for Google accounts it's already
  /// backed up to Drive and comes back on next sign-in (see
  /// cloud_sync_controller.dart); for Microsoft it re-resolves from
  /// SavedSources (kept, not deleted here) on next sign-in. Local file
  /// imports (ownerAccount is null) are untouched. Cascades to remove
  /// this account's tracks from any playlist via PlaylistTracks' trackId
  /// foreign key (ON DELETE CASCADE) — a shared playlist's own row (name/
  /// id) is not deleted, only its now-account-less membership rows.
  Future<void> deleteForAccount(String accountEmail) =>
      (delete(tracks)..where((t) => t.ownerAccount.equals(accountEmail))).go();

  Future<void> setFavorite(String id, bool value) =>
      (update(tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(isFavorite: Value(value)),
      );

  Future<void> cacheLyrics(String id, {String? lrc, String? plain}) =>
      (update(tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(lyricsLrc: Value(lrc), lyricsPlain: Value(plain)),
      );

  Future<void> setLyricsOffset(String id, int milliseconds) =>
      (update(tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(lyricsOffsetMs: Value(milliseconds)),
      );

  Future<void> setDownloadedPath(String id, String? path) =>
      (update(tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(downloadedPath: Value(path)),
      );
}
