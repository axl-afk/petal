import '../../models/auth_session.dart';

/// Thrown when a provider hasn't been configured with real credentials yet
/// (see auth_config.dart) — surfaced to the UI as a clear message rather
/// than a generic failure.
class AuthNotConfiguredException implements Exception {
  final String message;
  AuthNotConfiguredException(this.message);
  @override
  String toString() => message;
}

abstract class AuthProviderService {
  AuthProviderKind get kind;
  Future<AuthSession> signIn();
  Future<void> signOut();
}
