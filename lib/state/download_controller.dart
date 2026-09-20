import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/db/daos/track_dao.dart';
import '../data/db/tables.dart';
import '../data/services/auth/google_auth_service.dart';
import '../data/services/auth/microsoft_auth_service.dart';
import '../data/services/download_service.dart';
import 'providers.dart';

enum DownloadStatus { downloading, failed }

class TrackDownloadState {
  final DownloadStatus status;
  final double? progress;
  final String? error;
  const TrackDownloadState(this.status, {this.progress, this.error});
}

class DownloadController
    extends StateNotifier<Map<String, TrackDownloadState>> {
  final DownloadService _downloads;
  final TrackDao _tracks;
  final GoogleAuthService _google;
  final MicrosoftAuthService _microsoft;

  DownloadController(
    this._downloads,
    this._tracks,
    this._google,
    this._microsoft,
  ) : super(const {});

  Future<void> download(Track track) async {
    if (track.sourceType == TrackSourceType.local ||
        track.downloadedPath != null)
      return;
    state = {
      ...state,
      track.id: const TrackDownloadState(
        DownloadStatus.downloading,
        progress: 0,
      ),
    };
    try {
      final headers = await _headers(track);
      final path = await _downloads.download(
        trackId: track.id,
        uri: Uri.parse(track.sourceUri),
        headers: headers,
        extension: _extension(track),
        onProgress: (received, total) {
          state = {
            ...state,
            track.id: TrackDownloadState(
              DownloadStatus.downloading,
              progress: total == null || total <= 0 ? null : received / total,
            ),
          };
        },
      );
      await _tracks.setDownloadedPath(track.id, path);
      final next = {...state}..remove(track.id);
      state = next;
    } catch (error) {
      state = {
        ...state,
        track.id: TrackDownloadState(
          DownloadStatus.failed,
          error: error.toString(),
        ),
      };
    }
  }

  Future<void> remove(Track track) async {
    final path = track.downloadedPath;
    if (path == null) return;
    await _downloads.remove(path);
    await _tracks.setDownloadedPath(track.id, null);
  }

  Future<void> removeForAccount(String accountEmail) async {
    final tracks = await _tracks.getForAccount(accountEmail);
    for (final track in tracks) {
      final path = track.downloadedPath;
      if (path != null) await _downloads.remove(path);
    }
  }

  void dismissError(String trackId) {
    final next = {...state}..remove(trackId);
    state = next;
  }

  Future<Map<String, String>> _headers(Track track) async {
    if (track.sourceType == TrackSourceType.googleDrive) {
      final token = await _google.refreshAccessToken();
      if (token == null)
        throw StateError('Google access expired. Sign in again.');
      return {'Authorization': 'Bearer $token'};
    }
    if (track.sourceType == TrackSourceType.oneDrive) {
      final token = await _microsoft.accessToken();
      if (token == null)
        throw StateError('Microsoft access expired. Sign in again.');
      return {'Authorization': 'Bearer $token'};
    }
    return const {};
  }

  String _extension(Track track) {
    final mime = track.mimeType?.toLowerCase();
    if (mime == 'audio/mpeg') return '.mp3';
    if (mime == 'audio/mp4' || mime == 'audio/x-m4a') return '.m4a';
    if (mime == 'audio/flac') return '.flac';
    if (mime == 'audio/ogg') return '.ogg';
    if (mime == 'audio/wav' || mime == 'audio/x-wav') return '.wav';
    return '.audio';
  }
}

final downloadServiceProvider = Provider((ref) => DownloadService());

final downloadControllerProvider =
    StateNotifierProvider<DownloadController, Map<String, TrackDownloadState>>((
      ref,
    ) {
      return DownloadController(
        ref.watch(downloadServiceProvider),
        ref.watch(trackDaoProvider),
        ref.watch(googleAuthServiceProvider),
        ref.watch(microsoftAuthServiceProvider),
      );
    });
