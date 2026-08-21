// Platform-neutral types shared between the two LocalFileService
// implementations (local_file_service_io.dart / local_file_service_web.dart)
// — kept in their own file, with no dart:io or other platform-specific
// import, so both variants (and any caller) can depend on the same class
// without pulling in whichever implementation isn't relevant to the current
// compile target.

const kAudioExtensions = ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus'];

/// Everything Petal knows about one imported local file after tag reading —
/// real title/artist/album/genre/duration/artwork when the file has them,
/// filename-derived fallbacks when it doesn't (or when tag reading fails).
class ImportedAudioFile {
  final String id;
  final String storedPath;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int durationMs;
  final String? artworkPath;

  const ImportedAudioFile({
    required this.id,
    required this.storedPath,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.durationMs,
    this.artworkPath,
  });
}
