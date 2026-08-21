import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../../models/auth_session.dart';
import 'auth_config.dart';
import 'auth_service.dart';

/// Microsoft sign-in via a standard OAuth2 Authorization Code + PKCE flow
/// against the Microsoft identity platform (v2.0 endpoint) — this needs no
/// proprietary SDK, just your own Azure AD app registration (see
/// auth_config.dart). `flutter_web_auth_2` handles popping the system
/// browser/webview for the interactive part and capturing the redirect.
class MicrosoftAuthService implements AuthProviderService {
  @override
  AuthProviderKind get kind => AuthProviderKind.microsoft;

  static String get _authorizeEndpoint =>
      'https://login.microsoftonline.com/${AuthConfig.microsoftTenant}/oauth2/v2.0/authorize';
  static String get _tokenEndpoint =>
      'https://login.microsoftonline.com/${AuthConfig.microsoftTenant}/oauth2/v2.0/token';

  String _randomVerifier() {
    final rand = Random.secure();
    final bytes = List<int>.generate(64, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _challengeFor(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  @override
  Future<AuthSession> signIn() async {
    if (!AuthConfig.microsoftConfigured) {
      throw AuthNotConfiguredException(
        'Microsoft sign-in needs your own Azure AD app registration — see '
        'the setup checklist at the top of auth_config.dart.',
      );
    }

    final verifier = _randomVerifier();
    final challenge = _challengeFor(verifier);
    final state = _randomVerifier();

    final authUrl = Uri.parse(_authorizeEndpoint).replace(queryParameters: {
      'client_id': AuthConfig.microsoftClientId,
      'response_type': 'code',
      'redirect_uri': AuthConfig.microsoftRedirectUri,
      'response_mode': 'query',
      'scope': AuthConfig.microsoftScopes.join(' '),
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
    });

    final callbackScheme = Uri.parse(AuthConfig.microsoftRedirectUri).scheme;

    final resultUrl = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: callbackScheme,
    );

    final resultUri = Uri.parse(resultUrl);
    final code = resultUri.queryParameters['code'];
    final returnedState = resultUri.queryParameters['state'];
    if (code == null) {
      throw Exception('Microsoft sign-in did not return an authorization code.');
    }
    if (returnedState != state) {
      throw Exception('Microsoft sign-in state mismatch — possible CSRF, aborting.');
    }

    final tokenRes = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': AuthConfig.microsoftClientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': AuthConfig.microsoftRedirectUri,
        'code_verifier': verifier,
        'scope': AuthConfig.microsoftScopes.join(' '),
      },
    );

    if (tokenRes.statusCode != 200) {
      throw Exception('Microsoft token exchange failed: ${tokenRes.statusCode} ${tokenRes.body}');
    }

    final tokenJson = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    final accessToken = tokenJson['access_token'] as String?;
    final refreshToken = tokenJson['refresh_token'] as String?;
    final expiresIn = (tokenJson['expires_in'] as num?)?.toInt();
    final idToken = tokenJson['id_token'] as String?;

    final claims = idToken != null ? _decodeIdTokenClaims(idToken) : <String, dynamic>{};
    final email = (claims['preferred_username'] ?? claims['email'] ?? 'unknown@outlook.com') as String;
    final name = claims['name'] as String?;

    return AuthSession(
      provider: AuthProviderKind.microsoft,
      email: email,
      displayName: name,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiry: expiresIn != null ? DateTime.now().add(Duration(seconds: expiresIn)) : null,
    );
  }

  /// Decodes (without verifying — verification isn't needed client-side
  /// here since the token came directly from Microsoft over TLS via our own
  /// request) the JWT's payload segment to read basic profile claims.
  Map<String, dynamic> _decodeIdTokenClaims(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return {};
      var payload = parts[1];
      payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> signOut() async {
    // Stateless on the client side for the authorization-code flow — there's
    // no local session to tear down beyond what AuthController already
    // clears. A full sign-out that also ends the browser SSO session would
    // hit the /logout endpoint in a web view, which most desktop/mobile apps
    // intentionally skip.
  }
}
