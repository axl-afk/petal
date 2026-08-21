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

@DriftAccessor(tables: [Tracks])
class TrackDao extends DatabaseAccessor<AppDatabase> with _$TrackDaoMixin {
  TrackDao(super.db);

  Stream<List<Track>> watchAll() =>
      (select(tracks)..orderBy([(t) => OrderingTerm.asc(t.title)])).watch();

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

  Stream<List<Track>> watchFavorites() =>
      (select(tracks)
            ..where((t) => t.isFavorite.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.title)]))
          .watch();

  Future<Track?> getById(String id) =>
      (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();

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

  /// Full-text search over title/artist/album/genre using the tracks_fts
  /// FTS5 virtual table (see AppDatabase._createFts). Falls back to a plain
  /// LIKE scan if FTS5 isn't available for some reason (e.g. an older
  /// bundled sqlite3), so search never just breaks.
  Future<List<Track>> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      return (select(tracks)..orderBy([(t) => OrderingTerm.asc(t.title)])).get();
    }

    final ftsQuery = _toFtsPrefixQuery(query);
    try {
      final rows = await customSelect(
        'SELECT tracks.* FROM tracks_fts '
        'JOIN tracks ON tracks.rowid = tracks_fts.rowid '
        'WHERE tracks_fts MATCH ? '
        'ORDER BY rank',
        variables: [Variable.withString(ftsQuery)],
        readsFrom: {tracks},
      ).get();
      return rows.map((r) => tracks.map(r.data)).toList();
    } catch (_) {
      final like = '%${query.replaceAll('%', '')}%';
      return (select(tracks)
            ..where((t) =>
                t.title.like(like) | t.artist.like(like) | t.album.like(like) | t.genre.like(like))
            ..orderBy([(t) => OrderingTerm.asc(t.title)]))
          .get();
    }
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
  Future<void> upsertAll(List<TracksCompanion> items) async {
    for (final item in items) {
      final id = item.id.value;
      final existing = await (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();
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
          ),
        );
      }
    }
  }

  Future<void> deleteById(String id) =>
      (delete(tracks)..where((t) => t.id.equals(id))).go();

  Future<void> setFavorite(String id, bool value) =>
      (update(tracks)..where((t) => t.id.equals(id)))
          .write(TracksCompanion(isFavorite: Value(value)));

  Future<void> cacheLyrics(String id, {String? lrc, String? plain}) =>
      (update(tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(lyricsLrc: Value(lrc), lyricsPlain: Value(plain)),
      );
}
