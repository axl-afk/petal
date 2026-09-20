import 'package:drift/drift.dart' show Value;

import '../../utils/id_gen.dart';
import '../db/app_database.dart';
import '../db/daos/playlist_dao.dart';
import '../db/daos/source_dao.dart';
import '../db/daos/track_dao.dart';
import '../db/tables.dart';
import 'link_resolver_service.dart';

/// Translates between the on-device drift tables and the small JSON shape
/// backed up to/from Google Drive (see cloud_backup_service.dart). Only
/// covers the parts of the library that make sense to carry between
/// devices: pasted Drive/OneDrive/direct links, their favorite status, and
/// playlists built from them.
///
/// Locally-imported files are deliberately left out of the snapshot — the
/// actual audio bytes only exist on the device that imported them, so
/// backing up just the metadata would leave a phantom entry on another
/// device that can never actually play. See README's "How library backup
/// works".
///
/// The sync model is intentionally simple: [applySnapshot] only ever adds
/// or updates rows (upsert), never deletes, and [buildSnapshot] always
/// uploads this device's *complete* current account-scoped state. That
/// means removing a saved source/playlist on one device won't remove it
/// from Drive or from another device that syncs later — a real limitation,
/// but a predictable and safe one (nothing is ever silently lost), and a
/// deliberate trade-off against the complexity of real multi-device
/// merge/delete tracking.
class LibrarySyncService {
  final TrackDao trackDao;
  final PlaylistDao playlistDao;
  final SourceDao sourceDao;
  final LinkResolverService resolver;

  LibrarySyncService(
    this.trackDao,
    this.playlistDao,
    this.sourceDao,
    this.resolver,
  );

  Future<Map<String, dynamic>> buildSnapshot(String accountEmail) async {
    final sources = await sourceDao.getForAccount(accountEmail);
    final sourceOut = <Map<String, dynamic>>[];
    final cloudIds = <String>{};

    for (final s in sources) {
      final id = idForCloudSource(s.rawLink);
      cloudIds.add(id);
      final track = await trackDao.getById(id);
      sourceOut.add({
        'id': id,
        'provider': s.provider.name,
        'rawLink': s.rawLink,
        'label': s.label,
        'isFavorite': track?.isFavorite ?? false,
      });
    }

    final portableTracks = await trackDao.getForAccount(accountEmail);
    cloudIds.addAll(
      portableTracks
          .where((track) => track.sourceType != TrackSourceType.local)
          .map((track) => track.id),
    );
    final trackOut = portableTracks
        .where((track) => track.sourceType != TrackSourceType.local)
        .map(
          (track) => {
            'id': track.id,
            'provider': track.sourceType.name,
            'providerItemId': track.providerItemId,
            'originUri': track.originUri,
            'title': track.title,
            'artist': track.artist,
            'album': track.album,
            'genre': track.genre,
            'durationMs': track.durationMs,
            'mimeType': track.mimeType,
            'fileSizeBytes': track.fileSizeBytes,
            'remoteModifiedAt': track.remoteModifiedAt?.toIso8601String(),
            'artworkUrl': track.artworkUrl,
            'isFavorite': track.isFavorite,
          },
        )
        .toList();

    final playlists = await playlistDao.watchAll().first;
    final playlistOut = <Map<String, dynamic>>[];
    for (final p in playlists) {
      final tracks = await playlistDao.watchTracks(p.id).first;
      final trackIds = tracks
          .map((t) => t.id)
          .where(cloudIds.contains)
          .toList();
      if (trackIds.isEmpty) continue; // nothing cloud-portable in this playlist
      playlistOut.add({
        'id': p.id,
        'name': p.name,
        'createdAt': p.createdAt.toIso8601String(),
        'trackIds': trackIds,
      });
    }

    return {
      'schemaVersion': 2,
      'updatedAt': DateTime.now().toIso8601String(),
      'tracks': trackOut,
      'sources': sourceOut,
      'playlists': playlistOut,
    };
  }

  Future<void> applySnapshot(
    Map<String, dynamic> snapshot,
    String accountEmail,
  ) async {
    final tracks = ((snapshot['tracks'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>();
    for (final item in tracks) {
      final id = item['id'] as String?;
      final providerName = item['provider'] as String?;
      if (id == null || providerName == null) continue;
      final provider = TrackSourceType.values.firstWhere(
        (value) => value.name == providerName,
        orElse: () => TrackSourceType.direct,
      );
      final providerItemId = item['providerItemId'] as String?;
      final originUri = item['originUri'] as String? ?? '';
      String? streamUri;
      if (provider == TrackSourceType.googleDrive && providerItemId != null) {
        streamUri =
            'https://www.googleapis.com/drive/v3/files/$providerItemId?alt=media';
      } else if (provider == TrackSourceType.oneDrive &&
          providerItemId != null) {
        streamUri =
            'https://graph.microsoft.com/v1.0/me/drive/items/$providerItemId/content';
      } else {
        final resolved = resolver.resolve(originUri);
        if (resolved.ok) streamUri = resolved.playableUri;
      }
      if (streamUri == null) continue;

      await trackDao.upsert(
        TracksCompanion.insert(
          id: id,
          title: (item['title'] as String?)?.trim().isNotEmpty == true
              ? item['title'] as String
              : 'Untitled Track',
          artist: Value(item['artist'] as String? ?? 'Unknown Artist'),
          album: Value(item['album'] as String? ?? ''),
          genre: Value(item['genre'] as String? ?? ''),
          durationMs: Value((item['durationMs'] as num?)?.toInt() ?? 0),
          sourceType: provider,
          sourceUri: streamUri,
          originUri: originUri,
          ownerAccount: Value(accountEmail),
          providerItemId: Value(providerItemId),
          mimeType: Value(item['mimeType'] as String?),
          fileSizeBytes: Value((item['fileSizeBytes'] as num?)?.toInt() ?? 0),
          remoteModifiedAt: Value(
            DateTime.tryParse(item['remoteModifiedAt']?.toString() ?? ''),
          ),
          artworkUrl: Value(item['artworkUrl'] as String?),
          isFavorite: Value(item['isFavorite'] == true),
        ),
      );
    }

    final sources = ((snapshot['sources'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>();

    for (final s in sources) {
      final rawLink = s['rawLink'] as String?;
      if (rawLink == null || rawLink.isEmpty) continue;

      final resolved = resolver.resolve(rawLink);
      if (!resolved.ok || resolved.playableUri == null) continue;

      final id = idForCloudSource(rawLink);
      final providerName = s['provider'] as String?;
      final sourceType = TrackSourceType.values.firstWhere(
        (t) => t.name == providerName,
        orElse: () => TrackSourceType.direct,
      );
      final label = s['label'] as String?;

      await trackDao.upsert(
        TracksCompanion.insert(
          id: id,
          title: (label != null && label.trim().isNotEmpty)
              ? label
              : 'Untitled Track',
          sourceType: sourceType,
          sourceUri: resolved.playableUri!,
          originUri: rawLink,
          ownerAccount: Value(accountEmail),
        ),
      );

      if (s['isFavorite'] == true) {
        await trackDao.setFavorite(id, true);
      }

      await sourceDao.upsertForAccount(
        accountEmail: accountEmail,
        provider: sourceType,
        rawLink: rawLink,
        label: label,
      );
    }

    final playlists = ((snapshot['playlists'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>();
    for (final p in playlists) {
      final id = p['id'] as String?;
      final name = p['name'] as String?;
      if (id == null || name == null) continue;

      await playlistDao.ensureExists(id: id, name: name);

      final trackIds = ((p['trackIds'] as List<dynamic>?) ?? const [])
          .whereType<String>();
      for (final trackId in trackIds) {
        final track = await trackDao.getById(trackId);
        if (track == null) continue; // its source failed to resolve above — skip rather than add a dangling reference
        await playlistDao.addTrack(id, trackId);
      }
    }
  }
}
