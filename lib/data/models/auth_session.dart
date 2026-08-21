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

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'email': email,
        'displayName': displayName,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
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
