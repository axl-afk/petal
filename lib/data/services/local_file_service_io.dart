import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
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

  /// The fast, common-case scan: just the OS's known Music folder, on the
  /// three desktop platforms — returns null (not an error) if that folder
  /// doesn't exist or isn't accessible. For a real whole-disk crawl, see
  /// scanWholeComputer below.
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

  /// A real, literal whole-computer scan — every user-accessible drive/
  /// volume, not just the OS Music folder "Scan Music folder" (above)
  /// covers. Desktop only (see scanWholePhone-equivalent note in
  /// LibraryController for why Android/iOS need a different mechanism
  /// entirely, not this). This is slower than the Music-folder scan by
  /// nature — it's walking far more of the disk — but skips the specific
  /// places that would otherwise make it *pathologically* slow or just
  /// noisy: hidden directories (dotfiles/dotfolders — build caches, package
  /// manager stores, VCS internals) and OS-owned directories that are
  /// either permission-denied for a normal user anyway or never contain
  /// personal music (Windows/Program Files, macOS/System+Library,
  /// Linux/proc+sys+dev). [onProgress], if given, is called after every
  /// newly-found file so a caller can show a live count during a scan that
  /// might run for tens of seconds to minutes on a large or slow disk.
  Future<List<String>> scanWholeComputer({void Function(int foundSoFar)? onProgress}) async {
    final found = <String>[];
    for (final root in await _wholeComputerRoots()) {
      await _scanTreeSkippingNoise(root, found, onProgress);
    }
    return found;
  }

  // Dotfiles/dotfolders (.git, .cache, .npm, .cargo, .dart_tool, etc.) are
  // already skipped separately below by name.startsWith('.') — not
  // repeated here.
  static const _wholeComputerSkipDirs = {
    // Windows
    'windows', 'program files', 'program files (x86)', 'programdata',
    r'$recycle.bin', 'system volume information',
    // macOS
    'system', 'library', 'applications',
    // Linux
    'proc', 'sys', 'dev', 'run', 'boot', 'snap', 'lost+found',
    // cross-platform noise that can be enormous and is never personal music
    'node_modules',
  };

  Future<List<Directory>> _wholeComputerRoots() async {
    final roots = <Directory>[];
    if (Platform.isWindows) {
      for (final letter in 'CDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
        final d = Directory('$letter:\\');
        if (await d.exists()) roots.add(d);
      }
    } else if (Platform.isMacOS) {
      // /Users (every account's home, incl. Music/Downloads/Desktop/etc.)
      // and /Volumes (mounted external/network drives) — not literal `/`,
      // which is almost entirely OS-owned directories on macOS.
      if (await Directory('/Users').exists()) roots.add(Directory('/Users'));
      final volumes = Directory('/Volumes');
      if (await volumes.exists()) {
        try {
          await for (final v in volumes.list(followLinks: false)) {
            if (v is Directory) roots.add(v);
          }
        } catch (_) {/* ignore, use whatever roots were already found */}
      }
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && await Directory(home).exists()) roots.add(Directory(home));
      // Common external-drive mount points on Linux desktops.
      for (final mountBase in ['/media', '/mnt']) {
        final d = Directory(mountBase);
        if (await d.exists()) roots.add(d);
      }
    }
    return roots;
  }

  /// Manual recursive walk (not `Directory.list(recursive: true)`) so a
  /// skip-listed directory can be pruned *before* descending into it —
  /// walking into e.g. Program Files or .cache first and filtering after
  /// would defeat the entire point of skipping them.
  Future<void> _scanTreeSkippingNoise(
    Directory dir,
    List<String> found,
    void Function(int)? onProgress, {
    int depth = 0,
  }) async {
    if (depth > 40) return; // guards against a pathological symlink loop
    List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } catch (_) {
      return; // permission denied, or it vanished mid-scan — just skip it
    }
    for (final entity in entries) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue; // hidden files/folders
      if (entity is Directory) {
        if (_wholeComputerSkipDirs.contains(name.toLowerCase())) continue;
        await _scanTreeSkippingNoise(entity, found, onProgress, depth: depth + 1);
      } else if (entity is File) {
        final ext = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
        if (kAudioExtensions.contains(ext)) {
          found.add(entity.path);
          onProgress?.call(found.length);
        }
      }
    }
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
  /// Tag reading goes through `audio_metadata_reader` — pure Dart, no
  /// native/FFI bridge on any platform. This project originally used
  /// `audiotags`, which turned out to have a real, long-open,
  /// maintainer-unresponsive bug that broke every macOS and iOS build (a
  /// mismatch between its bundled native header and its compiled library —
  /// see pubspec.yaml's dependency comment for the issue links). Switching
  /// packages removes that entire failure class rather than working around
  /// it. Runtime failures (a file with corrupt/missing tags, or a format
  /// this package can't parse) are handled below — this falls back to the
  /// filename-derived title rather than failing the whole import.
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
      // readMetadata is synchronous (not a Future) — audio_metadata_reader
      // parses the file directly rather than round-tripping through a
      // native/FFI call. getImage:true is required to actually populate
      // `pictures` below; it defaults to false (skipped) otherwise.
      final tag = readMetadata(storedFile, getImage: true);
      if ((tag.title ?? '').trim().isNotEmpty) title = tag.title!.trim();
      if ((tag.artist ?? '').trim().isNotEmpty) artist = tag.artist!.trim();
      if ((tag.album ?? '').trim().isNotEmpty) album = tag.album!.trim();
      if (tag.genres.isNotEmpty) genre = tag.genres.join(', ');
      if (tag.duration != null) durationMs = tag.duration!.inMilliseconds;

      if (tag.pictures.isNotEmpty) {
        final pic = tag.pictures.first;
        // Cap embedded artwork at 8MB before writing — a defensive bound
        // against a maliciously/oddly tagged file dumping an oversized
        // blob into app storage (found during a security review; low
        // risk since the "attacker" is whoever's importing their own
        // file, but free to add).
        if (pic.bytes.length <= 8 * 1024 * 1024) {
          final artDir = await _ensureSubdir('artwork');
          // pic.mimetype (audio_metadata_reader's actual field name, lower-
          // case 't') is a plain String like "image/png"/"image/jpeg" —
          // unlike audiotags' generated MimeType enum, this needs no
          // toString() workaround to inspect.
          final artExt = pic.mimetype.toLowerCase().contains('png') ? '.png' : '.jpg';
          final artFile = File(p.join(artDir.path, '$id$artExt'));
          await artFile.writeAsBytes(pic.bytes, flush: true);
          artworkPath = artFile.path;
        }
      }
    } on MetadataParserException {
      // No usable tags, or this file type isn't one the package can parse
      // (covers both NoMetadataParserException and a parse failure on a
      // corrupt file) — keep the filename-derived fallbacks above rather
      // than failing the whole import over missing metadata.
    } catch (_) {
      // Any other unexpected failure reading tags — same fallback; a bad
      // tag block in one file shouldn't fail the import.
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
