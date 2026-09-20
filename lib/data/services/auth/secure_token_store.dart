import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps OAuth credentials in the platform keychain/credential vault.
/// Account profile data may live in SharedPreferences, but bearer and
/// refresh tokens must never be written there or to the library database.
class SecureTokenStore {
  static const _microsoftAccess = 'microsoft_access_token';
  static const _microsoftRefresh = 'microsoft_refresh_token';
  static const _microsoftExpiry = 'microsoft_access_token_expiry';

  final FlutterSecureStorage _storage;

  const SecureTokenStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  Future<void> saveMicrosoft({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    await _storage.write(key: _microsoftAccess, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _microsoftRefresh, value: refreshToken);
    }
    if (expiresAt != null) {
      await _storage.write(
        key: _microsoftExpiry,
        value: expiresAt.toUtc().toIso8601String(),
      );
    }
  }

  Future<String?> microsoftAccessToken() =>
      _storage.read(key: _microsoftAccess);
  Future<String?> microsoftRefreshToken() =>
      _storage.read(key: _microsoftRefresh);

  Future<DateTime?> microsoftExpiry() async {
    final raw = await _storage.read(key: _microsoftExpiry);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> clearMicrosoft() async {
    await Future.wait([
      _storage.delete(key: _microsoftAccess),
      _storage.delete(key: _microsoftRefresh),
      _storage.delete(key: _microsoftExpiry),
    ]);
  }
}
