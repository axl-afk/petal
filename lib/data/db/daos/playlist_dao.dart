import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'playlist_dao.g.dart';

@DriftAccessor(tables: [Playlists, PlaylistTracks, Tracks])
class PlaylistDao extends DatabaseAccessor<AppDatabase> with _$PlaylistDaoMixin {
  PlaylistDao(super.db);

  Stream<List<Playlist>> watchAll() =>
      (select(playlists)..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).watch();

  Future<Playlist> create(String name) async {
    final playlist = PlaylistsCompanion.insert(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
    );
    await into(playlists).insert(playlist);
    return (select(playlists)..where((p) => p.id.equals(playlist.id.value))).getSingle();
  }

  Future<void> rename(String id, String name) =>
      (update(playlists)..where((p) => p.id.equals(id)))
          .write(PlaylistsCompanion(name: Value(name)));

  /// Creates a playlist with a caller-chosen id if one doesn't already
  /// exist with that id — unlike [create] (which always mints its own id),
  /// this is for cloud-backup restore (LibrarySyncService.applySnapshot),
  /// where the id has to match what's in the pulled snapshot so playlist
  /// membership lines up across devices.
  Future<void> ensureExists({required String id, required String name}) async {
    final existing = await (select(playlists)..where((p) => p.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      await into(playlists).insert(PlaylistsCompanion.insert(id: id, name: name));
    }
  }

  // Named deletePlaylist rather than delete — drift's DatabaseAccessor
  // already defines a delete<T,D>(TableInfo<T,D> table) method, and a
  // same-named override with an incompatible signature is a compile error
  // (this broke `flutter build web` with exactly that error), and also
  // silently hijacked removeTrack()'s call to the inherited delete() below.
  Future<void> deletePlaylist(String id) =>
      (db.delete(playlists)..where((p) => p.id.equals(id))).go();

  Stream<List<Track>> watchTracks(String playlistId) {
    final query = select(playlistTracks).join([
      innerJoin(tracks, tracks.id.equalsExp(playlistTracks.trackId)),
    ])
      ..where(playlistTracks.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistTracks.position)]);
    return query.watch().map((rows) => rows.map((r) => r.readTable(tracks)).toList());
  }

  Future<void> addTrack(String playlistId, String trackId) async {
    final existingCount = await (selectOnly(playlistTracks)
          ..addColumns([playlistTracks.trackId.count()])
          ..where(playlistTracks.playlistId.equals(playlistId)))
        .map((r) => r.read(playlistTracks.trackId.count()) ?? 0)
        .getSingle();

    await into(playlistTracks).insertOnConflictUpdate(
      PlaylistTracksCompanion.insert(
        playlistId: playlistId,
        trackId: trackId,
        position: Value(existingCount),
      ),
    );
  }

  Future<void> removeTrack(String playlistId, String trackId) =>
      (delete(playlistTracks)
            ..where((pt) => pt.playlistId.equals(playlistId) & pt.trackId.equals(trackId)))
          .go();
}
