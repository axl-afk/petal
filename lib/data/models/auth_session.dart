import 'dart:convert';

enum AuthProviderKind { google, microsoft }

/// The signed-in account, persisted locally so the app can auto-reconnect
/// the account's saved Drive/OneDrive links on next launch without the user
/// having to sign in or re-paste links again.
class AuthSession {
  final AuthProviderKind provider;
  final String email;
  final String? displayName;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? accessTokenExpiry;

  const AuthSession({
    required this.provider,
    required this.email,
    this.displayName,
    this.accessToken,
    this.refreshToken,
    this.accessTokenExpiry,
  });

  // Security review finding: accessToken/refreshToken were being persisted
  // into shared_preferences (plaintext-ish, unencrypted storage on every
  // platform this app ships to — see README) despite nothing in the app
  // ever reading them back. Google's token is always re-derived fresh via
  // GoogleAuthService.refreshAccessToken() (silent re-auth) rather than
  // reused from a stored value, and no Microsoft refresh flow exists at
  // all. So persisting either was pure exposure with zero functional
  // benefit — deliberately excluded from what gets written to disk. They
  // stay as real fields on this class (and are still populated in-memory
  // for the current run, from provider.signIn()) in case a future feature
  // needs them for the *current* session, but a *persisted-then-reloaded*
  // session will always come back with both null, and no code today
  // depends on them not being null.
  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'email': email,
        'displayName': displayName,
        'accessTokenExpiry': accessTokenExpiry?.toIso8601String(),
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        provider: AuthProviderKind.values.firstWhere(
          (p) => p.name == json['provider'],
          orElse: () => AuthProviderKind.google,
        ),
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        accessToken: json['accessToken'] as String?,
        refreshToken: json['refreshToken'] as String?,
        accessTokenExpiry: json['accessTokenExpiry'] != null
            ? DateTime.tryParse(json['accessTokenExpiry'] as String)
            : null,
      );

  static String encode(AuthSession s) => jsonEncode(s.toJson());
  static AuthSession decode(String raw) =>
      AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
