import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/db/daos/playlist_dao.dart';
import '../data/db/daos/source_dao.dart';
import '../data/db/daos/track_dao.dart';
import '../data/services/auth/google_auth_service.dart';
import '../data/services/auth/microsoft_auth_service.dart';
import '../data/services/auth/secure_token_store.dart';
import '../data/services/cloud_backup_service.dart';
import '../data/services/cloud_library_service.dart';
import '../data/services/drive_folder_service.dart';
import '../data/services/device_media_service.dart';
import '../data/services/library_sync_service.dart';
import '../data/services/link_resolver_service.dart';
import '../data/services/local_file_service.dart';
import '../data/services/microsoft_backup_service.dart';
import '../data/services/lyrics_service.dart';
import '../data/services/prefs_service.dart';

// --- database -----------------------------------------------------------

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final trackDaoProvider = Provider<TrackDao>(
  (ref) => ref.watch(appDatabaseProvider).trackDao,
);
final playlistDaoProvider = Provider<PlaylistDao>(
  (ref) => ref.watch(appDatabaseProvider).playlistDao,
);
final sourceDaoProvider = Provider<SourceDao>(
  (ref) => ref.watch(appDatabaseProvider).sourceDao,
);

// --- services -------------------------------------------------------------

final linkResolverServiceProvider = Provider((ref) => LinkResolverService());
final driveFolderServiceProvider = Provider((ref) => DriveFolderService());
final lyricsServiceProvider = Provider((ref) => LyricsService());
final localFileServiceProvider = Provider((ref) => LocalFileService());
final deviceMediaServiceProvider = Provider((ref) => DeviceMediaService());
final googleAuthServiceProvider = Provider((ref) => GoogleAuthService());
final secureTokenStoreProvider = Provider((ref) => const SecureTokenStore());
final microsoftAuthServiceProvider = Provider(
  (ref) => MicrosoftAuthService(ref.watch(secureTokenStoreProvider)),
);

// Google Drive "Application Data" library backup — see
// cloud_backup_service.dart / library_sync_service.dart / cloud_sync_controller.dart.
final cloudBackupServiceProvider = Provider((ref) => CloudBackupService());
final microsoftBackupServiceProvider = Provider(
  (ref) => MicrosoftBackupService(),
);
final cloudLibraryServiceProvider = Provider((ref) => CloudLibraryService());
final librarySyncServiceProvider = Provider(
  (ref) => LibrarySyncService(
    ref.watch(trackDaoProvider),
    ref.watch(playlistDaoProvider),
    ref.watch(sourceDaoProvider),
    ref.watch(linkResolverServiceProvider),
  ),
);

/// Overridden in main.dart with a real, already-initialized PrefsService
/// (SharedPreferences.getInstance() is async, so it's awaited once at
/// startup rather than modeled as a FutureProvider everywhere downstream
/// has to unwrap).
final prefsServiceProvider = Provider<PrefsService>((ref) {
  throw UnimplementedError(
    'prefsServiceProvider must be overridden in main.dart after PrefsService.create()',
  );
});
