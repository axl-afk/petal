import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/db/daos/playlist_dao.dart';
import '../data/db/daos/source_dao.dart';
import '../data/db/daos/track_dao.dart';
import '../data/services/auth/google_auth_service.dart';
import '../data/services/auth/microsoft_auth_service.dart';
import '../data/services/link_resolver_service.dart';
import '../data/services/local_file_service.dart';
import '../data/services/lyrics_service.dart';
import '../data/services/prefs_service.dart';

// --- database -----------------------------------------------------------

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final trackDaoProvider = Provider<TrackDao>((ref) => ref.watch(appDatabaseProvider).trackDao);
final playlistDaoProvider = Provider<PlaylistDao>((ref) => ref.watch(appDatabaseProvider).playlistDao);
final sourceDaoProvider = Provider<SourceDao>((ref) => ref.watch(appDatabaseProvider).sourceDao);

// --- services -------------------------------------------------------------

final linkResolverServiceProvider = Provider((ref) => LinkResolverService());
final lyricsServiceProvider = Provider((ref) => LyricsService());
final localFileServiceProvider = Provider((ref) => LocalFileService());
final googleAuthServiceProvider = Provider((ref) => GoogleAuthService());
final microsoftAuthServiceProvider = Provider((ref) => MicrosoftAuthService());

/// Overridden in main.dart with a real, already-initialized PrefsService
/// (SharedPreferences.getInstance() is async, so it's awaited once at
/// startup rather than modeled as a FutureProvider everywhere downstream
/// has to unwrap).
final prefsServiceProvider = Provider<PrefsService>((ref) {
  throw UnimplementedError('prefsServiceProvider must be overridden in main.dart after PrefsService.create()');
});
