import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/auth_session.dart';
import 'auth_config.dart';
import 'auth_service.dart';

/// Google sign-in for Android, iOS, macOS and web. Platform OAuth clients
/// and the Web client ID must be configured as described in the README.
class GoogleAuthService implements AuthProviderService {
  @override
  AuthProviderKind get kind => AuthProviderKind.google;

  bool get _supported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

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
        // Read-only access to the user's actual Drive files (not just this
        // app's hidden appdata folder above) — needed so "paste a Drive
        // *folder* link" can list what's inside it and pull each audio file
        // (see DriveFolderService, LibraryController._connectDriveFolder).
        // This is a meaningfully bigger permission grant than drive.appdata
        // alone: the account is asked to let Petal see file names/contents
        // across their whole Drive, not just its own private blob. Google's
        // consent screen will flag this as sensitive the same way appdata
        // is — see the note above and README's "Sign-in setup" section,
        // which documents this explicitly so it isn't a surprise.
        'https://www.googleapis.com/auth/drive.readonly',
      ],
      // The Web OAuth client is used directly in the browser, but Android
      // expects it as serverClientId when google-services.json is absent.
      // Apple platforms instead use GIDClientID in their Info.plist.
      clientId: kIsWeb && AuthConfig.googleConfigured
          ? AuthConfig.googleWebClientId
          : null,
      serverClientId:
          !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android &&
              AuthConfig.googleConfigured
          ? AuthConfig.googleWebClientId
          : null,
    );
  }

  @override
  Future<AuthSession> signIn() async {
    if (!_supported) {
      throw AuthNotConfiguredException(
        'Google sign-in is available on Android, iOS, macOS and web. '
        'Windows and Linux need a separate desktop OAuth implementation.',
      );
    }
    if ((kIsWeb || defaultTargetPlatform == TargetPlatform.android) &&
        !AuthConfig.googleConfigured) {
      throw AuthNotConfiguredException(
        'Set PETAL_GOOGLE_CLIENT_ID to your Google Web OAuth client ID. '
        'See the README sign-in setup.',
      );
    }
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
    if (!_supported) return null;
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
    if (!_supported) return;
    await _buildClient().signOut();
  }
}
