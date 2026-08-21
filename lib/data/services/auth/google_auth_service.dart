import 'package:google_sign_in/google_sign_in.dart';

import '../../models/auth_session.dart';
import 'auth_config.dart';
import 'auth_service.dart';

/// Real Google sign-in via the official `google_sign_in` package. Works
/// out of the box on Android once you've added your SHA-1 fingerprint in
/// the Google Cloud console (no client ID needed here for Android); iOS
/// needs GoogleService-Info.plist; web/desktop need [AuthConfig.googleWebClientId].
/// See auth_config.dart for the full setup checklist.
class GoogleAuthService implements AuthProviderService {
  @override
  AuthProviderKind get kind => AuthProviderKind.google;

  GoogleSignIn _buildClient() {
    return GoogleSignIn(
      scopes: const [
        'email',
        'profile',
        // Drive's "Application Data" folder — a hidden per-app storage area
        // inside the user's own Drive that never shows up in their normal
        // Drive UI and that only this app can read or write. This is the
        // whole mechanism behind the library backup in
        // cloud_backup_service.dart: no Petal-run server, no access to any
        // of the user's actual Drive files, just one small JSON blob this
        // app owns inside their account. See README's "How library backup
        // works". Note: Google's OAuth consent screen treats this as a
        // "sensitive" scope — until you verify your app in Google Cloud
        // Console, sign-in will show an "unverified app" warning to anyone
        // who isn't added as a test user on your project.
        'https://www.googleapis.com/auth/drive.appdata',
      ],
      clientId: AuthConfig.googleConfigured ? AuthConfig.googleWebClientId : null,
    );
  }

  @override
  Future<AuthSession> signIn() async {
    final client = _buildClient();
    final account = await client.signIn();
    if (account == null) {
      throw AuthNotConfiguredException('Sign-in was cancelled.');
    }
    final auth = await account.authentication;

    return AuthSession(
      provider: AuthProviderKind.google,
      email: account.email,
      displayName: account.displayName,
      accessToken: auth.accessToken,
    );
  }

  /// Re-authenticates silently (no UI) to get a fresh access token. Google
  /// access tokens expire after about an hour, so a session that's been
  /// open longer than that (or resumed from a persisted session on a later
  /// launch) needs this before any Drive API call rather than reusing the
  /// token captured at sign-in time. Returns null if silent re-auth isn't
  /// possible (e.g. offline, or the grant was revoked) — callers treat that
  /// as "skip this sync, try again next time" rather than an error.
  Future<String?> refreshAccessToken() async {
    final client = _buildClient();
    try {
      final account = await client.signInSilently();
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.accessToken;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    await _buildClient().signOut();
  }
}
