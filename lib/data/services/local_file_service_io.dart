import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/id_gen.dart';
import 'local_file_types.dart';

/// Local-file import — desktop/mobile only. This file is only ever compiled
/// in on platforms where dart:io is available; local_file_service.dart
/// conditionally exports local_file_service_web.dart (a stub with no
/// dart:io dependency) on web instead, and LibraryController.importLocalFiles
/// additionally guards every call behind kIsWeb — matching the product
/// decision that the web build never touches the local filesystem, only
/// the installed app does.
class LocalFileService {
  /// Multi-file picker — unchanged behavior, just individual files.
  Future<List<String>> pickAudioFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kAudioExtensions,
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return [];
    return result.files.where((f) => f.path != null).map((f) => f.path!).toList();
  }

  /// Folder picker + recursive scan — finds every audio file anywhere under
  /// the chosen folder, including subfolders, matching how most desktop
  /// music apps "import a library" (point at one folder, not one file at a
  /// time).
  Future<String?> pickAudioFolder() => FilePicker.platform.getDirectoryPath();

  Future<List<String>> scanFolderForAudio(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return [];
    final found = <String>[];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final ext = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
        if (kAudioExtensions.contains(ext)) found.add(entity.path);
      }
    } catch (_) {
      // A subfolder we don't have permission to read, or it vanished mid-scan
      // — keep whatever was already found rather than failing the whole scan.
    }
    return found;
  }

  /// "Scan whole system" in the literal sense (crawl every file on the
  /// drive) isn't something any real music player actually does — it's slow
  /// and, on mobile, isn't even permitted without much heavier platform
  /// integration (MediaStore on Android, the Photos-library-style picker on
  /// iOS). What every desktop music player actually does instead is scan
  /// the OS's known Music folder. This does that, for the three desktop
  /// platforms — returns an empty list (not an error) if that folder
  /// doesn't exist or isn't accessible.
  Future<String?> platformMusicFolder() async {
    if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home == null) return null;
      final musicDir = p.join(home, 'Music');
      return await Directory(musicDir).exists() ? musicDir : null;
    }
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'];
      if (profile == null) return null;
      final musicDir = p.join(profile, 'Music');
      return await Directory(musicDir).exists() ? musicDir : null;
    }
    return null; // Android/iOS: no equivalent without MediaStore/Photos-style APIs.
  }

  /// Best-effort title from a bare filename: strip the extension, swap
  /// underscores/dashes for spaces, title-case it. Used whenever real tag
  /// reading fails or the file has no tags at all.
  String titleFromFileName(String fileName) {
    var name = fileName;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    name = name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    if (name.isEmpty) return 'Untitled';
    return name
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Copies the picked file into Petal's own app-storage folder and reads
  /// its embedded tags (title/artist/album/genre/duration/cover art).
  ///
  /// Copying into app storage — rather than just remembering the original
  /// path — is deliberate: on macOS specifically, a path handed back by the
  /// file picker is only guaranteed readable for as long as the picker's
  /// access grant lasts. Without setting up security-scoped bookmarks (a
  /// real but fiddlier fix), the app loses permission to that exact path
  /// the next time it launches — tracks would still show in the library
  /// (that's DB metadata, unaffected), but playback would silently fail
  /// with a permission error, because the sandbox denies the read. Copying
  /// once at import time sidesteps that entirely: once the file is inside
  /// Petal's own container, Petal owns it permanently on every platform.
  /// Trade-off: it uses roughly double the disk space of the original
  /// files. For a personal music library that's the safer default; ask if
  /// you'd rather trade that for security-scoped bookmarks instead.
  ///
  /// Tag reading goes through the `audiotags` package, the one new
  /// dependency this needs — its exact API surface is the least-certain
  /// part of this change (this project has never been through a real Dart
  /// compiler here — see README). If `flutter pub get` or the build fails
  /// specifically on `audiotags`, paste the error back and it'll get fixed
  /// the same way everything else in this repo has been: from the real
  /// compiler output. Runtime failures (a file with corrupt/missing tags)
  /// are already handled — this falls back to the filename-derived title
  /// rather than failing the whole import.
  Future<ImportedAudioFile> importFile(String originalPath) async {
    final id = idForLocalPath(originalPath);
    final ext = p.extension(originalPath);
    final fileName = p.basename(originalPath);

    final audioDir = await _ensureSubdir('audio');
    final storedFile = File(p.join(audioDir.path, '$id$ext'));
    if (!await storedFile.exists()) {
      await File(originalPath).copy(storedFile.path);
    }

    var title = titleFromFileName(fileName);
    var artist = 'Unknown Artist';
    var album = '';
    var genre = '';
    var durationMs = 0;
    String? artworkPath;

    try {
      final tag = await AudioTags.read(storedFile.path);
      if (tag != null) {
        if ((tag.title ?? '').trim().isNotEmpty) title = tag.title!.trim();
        if ((tag.trackArtist ?? '').trim().isNotEmpty) artist = tag.trackArtist!.trim();
        if ((tag.album ?? '').trim().isNotEmpty) album = tag.album!.trim();
        if ((tag.genre ?? '').trim().isNotEmpty) genre = tag.genre!.trim();
        if (tag.duration != null) durationMs = tag.duration! * 1000;

        if (tag.pictures.isNotEmpty) {
          final pic = tag.pictures.first;
          final artDir = await _ensureSubdir('artwork');
          final artExt = pic.mimeType.contains('png') ? '.png' : '.jpg';
          final artFile = File(p.join(artDir.path, '$id$artExt'));
          await artFile.writeAsBytes(pic.bytes, flush: true);
          artworkPath = artFile.path;
        }
      }
    } catch (_) {
      // No usable tags (or this file type/audiotags version doesn't support
      // reading it) — keep the filename-derived fallbacks above rather than
      // failing the import over missing metadata.
    }

    return ImportedAudioFile(
      id: id,
      storedPath: storedFile.path,
      title: title,
      artist: artist,
      album: album,
      genre: genre,
      durationMs: durationMs,
      artworkPath: artworkPath,
    );
  }

  Future<Directory> _ensureSubdir(String name) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
