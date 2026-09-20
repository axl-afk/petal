import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/auth/google_auth_service.dart';
import '../data/services/auth/microsoft_auth_service.dart';
import '../data/models/auth_session.dart';
import '../data/services/cloud_backup_service.dart';
import '../data/services/library_sync_service.dart';
import '../data/services/microsoft_backup_service.dart';
import 'providers.dart';

enum CloudSyncStatus { idle, syncing, error }

class CloudSyncState {
  final CloudSyncStatus status;
  final DateTime? lastSyncedAt;
  final String? error;

  const CloudSyncState({
    this.status = CloudSyncStatus.idle,
    this.lastSyncedAt,
    this.error,
  });

  CloudSyncState copyWith({
    CloudSyncStatus? status,
    DateTime? lastSyncedAt,
    String? error,
    bool clearError = false,
  }) => CloudSyncState(
    status: status ?? this.status,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Backs Petal's library (saved Drive/OneDrive links, favorites, playlists
/// — see LibrarySyncService) up to the signed-in Google account's own
/// Drive, instead of any server Petal itself runs. Two entry points:
///
/// - [syncAfterSignIn]: pull whatever's already backed up on this account
///   and merge it in, then push the merged result — so a fresh install
///   gets its library back, and a device with pre-existing local links
///   backs those up for the first time.
/// - [scheduleBackup]: debounced push after a local change (new link,
///   favorite toggle, playlist edit) while already signed in with Google.
///
/// See cloud_backup_service.dart's doc comment for why this whole feature
/// is the least-tested integration in the project (no real Google account
/// was available to exercise it against while building it) — and
/// library_sync_service.dart's doc comment for the "upsert-only, last full
/// state pushed wins" sync model this relies on.
class CloudSyncController extends StateNotifier<CloudSyncState> {
  final GoogleAuthService _google;
  final MicrosoftAuthService _microsoft;
  final CloudBackupService _backup;
  final MicrosoftBackupService _microsoftBackup;
  final LibrarySyncService _sync;
  Timer? _debounce;

  CloudSyncController(
    this._google,
    this._microsoft,
    this._backup,
    this._microsoftBackup,
    this._sync,
  ) : super(const CloudSyncState());

  Future<void> syncAfterSignIn(AuthSession session) async {
    state = state.copyWith(status: CloudSyncStatus.syncing, clearError: true);
    try {
      final token = await _tokenFor(session.provider);
      if (token == null) {
        throw CloudBackupException(
          'Could not refresh cloud access — try signing in again.',
        );
      }

      final remote = session.provider == AuthProviderKind.google
          ? await _backup.pull(token)
          : await _microsoftBackup.pull(token);
      if (remote != null) await _sync.applySnapshot(remote, session.email);

      final merged = await _sync.buildSnapshot(session.email);
      if (session.provider == AuthProviderKind.google) {
        await _backup.push(token, merged);
      } else {
        await _microsoftBackup.push(token, merged);
      }

      state = state.copyWith(
        status: CloudSyncStatus.idle,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        status: CloudSyncStatus.error,
        error: e.toString(),
      );
    }
  }

  void scheduleBackup(AuthSession session) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => _pushNow(session));
  }

  Future<void> _pushNow(AuthSession session) async {
    state = state.copyWith(status: CloudSyncStatus.syncing, clearError: true);
    try {
      final token = await _tokenFor(session.provider);
      if (token == null) {
        throw CloudBackupException(
          'Could not refresh cloud access — try signing in again.',
        );
      }
      final snapshot = await _sync.buildSnapshot(session.email);
      if (session.provider == AuthProviderKind.google) {
        await _backup.push(token, snapshot);
      } else {
        await _microsoftBackup.push(token, snapshot);
      }
      state = state.copyWith(
        status: CloudSyncStatus.idle,
        lastSyncedAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        status: CloudSyncStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<String?> _tokenFor(AuthProviderKind provider) =>
      provider == AuthProviderKind.google
      ? _google.refreshAccessToken()
      : _microsoft.accessToken();

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final cloudSyncControllerProvider =
    StateNotifierProvider<CloudSyncController, CloudSyncState>((ref) {
      return CloudSyncController(
        ref.watch(googleAuthServiceProvider),
        ref.watch(microsoftAuthServiceProvider),
        ref.watch(cloudBackupServiceProvider),
        ref.watch(microsoftBackupServiceProvider),
        ref.watch(librarySyncServiceProvider),
      );
    });
