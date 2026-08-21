import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/auth_session.dart';
import '../data/services/auth/auth_service.dart';
import '../data/services/prefs_service.dart';
import 'library_controller.dart';
import 'providers.dart';

class AuthState {
  final AuthSession? session;
  final bool loading;
  final String? error;

  const AuthState({this.session, this.loading = false, this.error});

  bool get isSignedIn => session != null;

  AuthState copyWith({AuthSession? session, bool? loading, String? error, bool clearSession = false}) {
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
      : super(AuthState(session: _prefs.loadSession()));

  Future<void> signIn(AuthProviderKind kind) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final provider = kind == AuthProviderKind.google ? _google : _microsoft;
      final session = await provider.signIn();
      await _prefs.saveSession(session);
      state = AuthState(session: session);

      // "once user login and setup drive links not need to do it again and
      // if the same id has drive it auto connect it to the player" —
      // re-resolve any links this account saved previously so the library
      // repopulates without the user re-pasting anything.
      await _ref.read(libraryControllerProvider.notifier).reconnectSavedSourcesForAccount(session.email);
    } catch (e) {
      state = state.copyWith(loading: false, error: e is AuthNotConfiguredException ? e.message : e.toString());
    }
  }

  Future<void> signOut() async {
    final kind = state.session?.provider;
    if (kind == AuthProviderKind.google) await _google.signOut();
    if (kind == AuthProviderKind.microsoft) await _microsoft.signOut();
    await _prefs.clearSession();
    state = const AuthState();
  }

  void dismissError() => state = state.copyWith(error: null);
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(prefsServiceProvider),
    ref.watch(googleAuthServiceProvider),
    ref.watch(microsoftAuthServiceProvider),
    ref,
  );
});
