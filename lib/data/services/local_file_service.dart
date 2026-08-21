import 'package:file_picker/file_picker.dart';

class PickedLocalFile {
  final String path;
  final String fileName;
  const PickedLocalFile({required this.path, required this.fileName});
}

/// Local-file import — desktop/mobile only. Callers are responsible for the
/// actual `kIsWeb` gate (see LibraryController.importLocalFiles), matching
/// the product decision that the web build never touches the local
/// filesystem, only the installed build does.
class LocalFileService {
  Future<List<PickedLocalFile>> pickAudioFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus'],
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return [];

    return result.files
        .where((f) => f.path != null)
        .map((f) => PickedLocalFile(path: f.path!, fileName: f.name))
        .toList();
  }

  /// Best-effort title from a bare filename: strip the extension, swap
  /// underscores/dashes for spaces, title-case it. Real tag reading (ID3 /
  /// MP4 atoms) is a good follow-up — e.g. the `audiotags` package — but was
  /// left out here to keep the dependency surface small for a project that
  /// couldn't be pub-get-verified in the environment that authored it.
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
}
