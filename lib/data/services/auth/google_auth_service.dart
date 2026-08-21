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
      scopes: const ['email', 'profile'],
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

  @override
  Future<void> signOut() async {
    await _buildClient().signOut();
  }
}
