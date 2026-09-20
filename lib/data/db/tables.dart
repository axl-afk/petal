import 'package:drift/drift.dart';

/// Where a track's bytes actually come from.
enum TrackSourceType { local, googleDrive, oneDrive, direct }

@DataClassName('Track')
class Tracks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist =>
      text().withDefault(const Constant('Unknown Artist'))();
  TextColumn get album => text().withDefault(const Constant(''))();
  TextColumn get genre => text().withDefault(const Constant(''))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  TextColumn get sourceType => textEnum<TrackSourceType>()();

  /// The URI actually handed to just_audio: a local file path, or a resolved
  /// direct-download URL for cloud links.
  TextColumn get sourceUri => text()();

  /// What the user originally pasted / picked (share link or local path) —
  /// kept so a cloud link can be re-resolved later if the direct URL expires.
  TextColumn get originUri => text()();

  TextColumn get artworkUrl => text().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// Signed-in account this track's source belongs to, so per-account cloud
  /// libraries stay separate. Null = local-only / no account.
  TextColumn get ownerAccount => text().nullable()();

  /// Stable item id from Drive/Graph. Expiring stream URLs are deliberately
  /// not used as identity.
  TextColumn get providerItemId => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get fileSizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get remoteModifiedAt => dateTime().nullable()();

  /// Private app-storage copy used when the user makes a cloud track
  /// available offline. Null means stream from the provider.
  TextColumn get downloadedPath => text().nullable()();

  /// Cached synced lyrics, stored as LRC text so we don't re-fetch every play.
  TextColumn get lyricsLrc => text().nullable()();
  TextColumn get lyricsPlain => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Playlist')
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlaylistTrack')
class PlaylistTracks extends Table {
  TextColumn get playlistId =>
      text().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get trackId =>
      text().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {playlistId, trackId};
}

/// A saved Drive/OneDrive share link. Kept separately from Tracks so the app
/// can re-resolve / re-import it (e.g. a whole shared folder in the future)
/// and so it can be tied to a signed-in account for auto-reconnect.
@DataClassName('SavedSource')
class SavedSources extends Table {
  TextColumn get id => text()();
  TextColumn get accountEmail => text().nullable()();
  TextColumn get provider => textEnum<TrackSourceType>()();
  TextColumn get rawLink => text()();
  TextColumn get label => text().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
