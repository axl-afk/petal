import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/auth_session.dart';
import '../data/services/auth/auth_service.dart';
import '../data/services/prefs_service.dart';
import 'cloud_sync_controller.dart';
import 'download_controller.dart';
import 'library_controller.dart';
import 'providers.dart';

class AuthState {
  final AuthSession? session;
  final bool loading;
  final String? error;

  const AuthState({this.session, this.loading = false, this.error});

  bool get isSignedIn => session != null;

  AuthState copyWith({
    AuthSession? session,
    bool? loading,
    String? error,
    bool clearSession = false,
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final PrefsService _prefs;
  final AuthProviderService _google;
  final AuthProviderService _microsoft;
  final Ref _ref;

  AuthController(this._prefs, this._google, this._microsoft, this._ref)
    : super(AuthState(session: _prefs.loadSession())) {
    final session = state.session;
    if (session != null) Future.microtask(() => _restoreSession(session));
  }

  Future<void> _restoreSession(AuthSession session) async {
    await _ref
        .read(cloudSyncControllerProvider.notifier)
        .syncAfterSignIn(session);
    try {
      await _ref.read(libraryControllerProvider.notifier).scanConnectedCloud();
    } catch (_) {
      // The cached local library remains usable offline. Settings exposes
      // the scan error and lets the user retry or reauthenticate.
    }
  }

  Future<void> signIn(AuthProviderKind kind) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final provider = kind == AuthProviderKind.google ? _google : _microsoft;
      final session = await provider.signIn();
      await _prefs.saveSession(session);
      state = AuthState(session: session);

      if (kind == AuthProviderKind.google) {
        // "app gonna keep the details on their google drive what they
        // added or not, so that i don't need a server for it" — a
        // Google-signed-in library restores from this account's own Drive
        // backup (see cloud_sync_controller.dart) rather than only from
        // this device's local SavedSources table, so switching devices or
        // reinstalling actually brings the library back.
        await _ref
            .read(cloudSyncControllerProvider.notifier)
            .syncAfterSignIn(session);
      } else {
        // "once user login and setup drive links not need to do it again and
        // if the same id has drive it auto connect it to the player" —
        // re-resolve any links this account saved previously so the library
        // repopulates without the user re-pasting anything. Microsoft/
        // OneDrive doesn't have the Drive-backup mechanism above (yet), so
        // this stays local-device-only for now.
        await _ref
            .read(libraryControllerProvider.notifier)
            .reconnectSavedSourcesForAccount(session.email);
        await _ref
            .read(cloudSyncControllerProvider.notifier)
            .syncAfterSignIn(session);
      }
      // Provider discovery is deliberately independent from restoring the
      // small metadata backup above: the user's cloud remains the source of
      // truth for audio bytes. A scan failure must not undo a successful
      // sign-in; LibraryState keeps the actionable error for the UI.
      try {
        await _ref
            .read(libraryControllerProvider.notifier)
            .scanConnectedCloud();
      } catch (_) {}
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e is AuthNotConfiguredException ? e.message : e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    final session = state.session;
    if (session?.provider == AuthProviderKind.google) await _google.signOut();
    if (session?.provider == AuthProviderKind.microsoft)
      await _microsoft.signOut();
    // Security review finding: local reads were never scoped by account, so
    // on a shared device the next person to open Petal — signed out, or
    // signed in as someone else — could still see and play every Drive/
    // OneDrive link this account had added. See TrackDao.deleteForAccount.
    if (session != null) {
      await _ref
          .read(downloadControllerProvider.notifier)
          .removeForAccount(session.email);
      await _ref
          .read(libraryControllerProvider.notifier)
          .clearAccountData(session.email);
    }
    await _prefs.clearSession();
    state = const AuthState();
  }

  void dismissError() => state = state.copyWith(error: null);
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      ref.watch(prefsServiceProvider),
      ref.watch(googleAuthServiceProvider),
      ref.watch(microsoftAuthServiceProvider),
      ref,
    );
  },
);
