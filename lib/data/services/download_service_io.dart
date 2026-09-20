import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final http.Client _client;
  DownloadService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> download({
    required String trackId,
    required Uri uri,
    required Map<String, String> headers,
    required String extension,
    void Function(int received, int? total)? onProgress,
  }) async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory(p.join(base.path, 'offline'));
    if (!await directory.exists()) await directory.create(recursive: true);
    final safeExtension = RegExp(r'^\.[a-zA-Z0-9]{1,8}$').hasMatch(extension)
        ? extension
        : '.audio';
    final destination = File(p.join(directory.path, '$trackId$safeExtension'));
    final temporary = File('${destination.path}.part');
    if (await temporary.exists()) await temporary.delete();

    final request = http.Request('GET', uri)..headers.addAll(headers);
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Download failed (HTTP ${response.statusCode}).',
        uri: uri,
      );
    }

    final sink = temporary.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, response.contentLength);
      }
      await sink.flush();
      await sink.close();
      if (received == 0)
        throw const FileSystemException('The provider returned an empty file.');
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
      return destination.path;
    } catch (_) {
      await sink.close();
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  Future<void> remove(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
