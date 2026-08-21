import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();

/// A *deterministic* id for a locally-imported file, derived from its
/// absolute source path. Using a random id per import (the old behavior)
/// meant re-importing the same file created a brand-new row instead of
/// updating the existing one — TrackDao.upsertAll uses INSERT OR REPLACE,
/// which only dedupes on a primary-key collision, so a fresh random id
/// every time bypassed that entirely and silently duplicated the library
/// on every re-import. Hashing the path instead means the same file always
/// maps to the same row.
String idForLocalPath(String absolutePath) {
  final bytes = utf8.encode(absolutePath);
  return 'local_${sha1.convert(bytes)}';
}

/// The same idea as [idForLocalPath], but for a cloud-linked track (Drive/
/// OneDrive/direct URL), derived from the raw link the user pasted.
/// Without this, both re-pasting the same link and reconnecting a saved
/// link after sign-in (`LibraryController.reconnectSavedSourcesForAccount`)
/// called `newId()` and created a brand-new row each time, silently
/// duplicating the cloud track on every reconnect. It also gives the
/// Google Drive library backup (cloud_backup_service.dart) a stable key to
/// reference a track by across devices — the raw internal Track.id can't
/// be reused as-is (a fresh install has no rows yet), but a hash of "what
/// the user pasted" lands on the same id everywhere.
String idForCloudSource(String rawLink) {
  final bytes = utf8.encode(rawLink.trim());
  return 'cloud_${sha1.convert(bytes)}';
}
