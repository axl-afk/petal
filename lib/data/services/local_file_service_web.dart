import 'local_file_types.dart';

/// Web stub for LocalFileService. Local file access — picking, recursive
/// folder scanning, embedded-tag reading, copying into app storage — has no
/// meaning inside a browser sandbox, and dart:io (which the real
/// implementation needs for all of that) isn't even available to import on
/// this compile target.
///
/// Every method here should be unreachable in practice:
/// LibraryController checks kIsWeb before calling any of them and throws
/// its own clear error first. This class exists only so the shared provider
/// graph (state/providers.dart constructs a LocalFileService unconditionally,
/// on every platform) compiles at all on web — see local_file_service.dart's
/// conditional export, which picks this file specifically when dart:io
/// isn't available.
class LocalFileService {
  Future<List<String>> pickAudioFiles() async => [];
  Future<String?> pickAudioFolder() async => null;
  Future<List<String>> scanFolderForAudio(String folderPath) async => [];
  Future<String?> platformMusicFolder() async => null;
  Future<List<String>> scanWholeComputer({void Function(int foundSoFar)? onProgress}) async => [];
  String titleFromFileName(String fileName) => fileName;

  Future<ImportedAudioFile> importFile(String originalPath) async =>
      throw UnsupportedError('Local file import is not available on web.');
}
