import 'package:drift/drift.dart';

import 'connection/connection.dart' as impl;
import 'daos/playlist_dao.dart';
import 'daos/source_dao.dart';
import 'daos/track_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Petal's on-device library database: tracks, playlists, and saved cloud
/// source links, plus an FTS5 virtual table (`tracks_fts`, created in
/// [_createFts]) that gives the Library search box real full-text search —
/// tokenized, prefix-matching, and ranked — instead of a linear scan.
///
/// Query-shape-driven indices live in [_createIndices]: every WHERE/GROUP BY
/// column the DAOs actually use (see track_dao.dart / source_dao.dart) is
/// covered, so filtering by artist/genre/favorite/account, and joining
/// playlist_tracks by track, all hit an index instead of a full table scan
/// as the library grows into the thousands of tracks.
@DriftDatabase(
  tables: [Tracks, Playlists, PlaylistTracks, SavedSources],
  daos: [TrackDao, PlaylistDao, SourceDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(impl.connect());

  /// For tests / tools that want to hand in their own executor.
  AppDatabase.withExecutor(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFts();
          await _createIndices();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // WAL lets the FTS sync triggers (writes) and the Library screen's
          // reactive stream queries (reads) proceed without blocking each
          // other — the whole reason drift/just_audio/riverpod's "watch a
          // query, rebuild on change" pattern stays smooth under real use.
          // No-op (and harmless) on backends where it doesn't apply.
          await customStatement('PRAGMA journal_mode=WAL');
        },
      );

  Future<void> _createIndices() async {
    await customStatement('CREATE INDEX IF NOT EXISTS idx_tracks_artist ON tracks(artist)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_tracks_genre ON tracks(genre)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_tracks_favorite ON tracks(is_favorite)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_tracks_owner_account ON tracks(owner_account)');
    // The composite primary key on playlist_tracks(playlist_id, track_id)
    // already gives SQLite a fast path for "tracks in this playlist" (the
    // common case, watchTracks()); this covers the reverse lookup direction.
    await customStatement('CREATE INDEX IF NOT EXISTS idx_playlist_tracks_track ON playlist_tracks(track_id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_saved_sources_account ON saved_sources(account_email)');
  }

  Future<void> _createFts() async {
    await customStatement(
      "CREATE VIRTUAL TABLE IF NOT EXISTS tracks_fts USING fts5("
      "title, artist, album, genre, content='tracks', content_rowid='rowid')",
    );

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS tracks_ai AFTER INSERT ON tracks BEGIN
        INSERT INTO tracks_fts(rowid, title, artist, album, genre)
        VALUES (new.rowid, new.title, new.artist, new.album, new.genre);
      END;
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS tracks_ad AFTER DELETE ON tracks BEGIN
        INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album, genre)
        VALUES('delete', old.rowid, old.title, old.artist, old.album, old.genre);
      END;
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS tracks_au AFTER UPDATE ON tracks BEGIN
        INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album, genre)
        VALUES('delete', old.rowid, old.title, old.artist, old.album, old.genre);
        INSERT INTO tracks_fts(rowid, title, artist, album, genre)
        VALUES (new.rowid, new.title, new.artist, new.album, new.genre);
      END;
    ''');
  }
}
