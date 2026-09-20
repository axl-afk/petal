class DownloadService {
  Future<String> download({
    required String trackId,
    required Uri uri,
    required Map<String, String> headers,
    required String extension,
    void Function(int received, int? total)? onProgress,
  }) => throw UnsupportedError(
    'Offline downloads are available in the installed Petal app.',
  );

  Future<void> remove(String path) async {}
}
