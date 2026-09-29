/// ============================================================================
/// PLACEHOLDER OAUTH CREDENTIALS — READ BEFORE SHIPPING
/// ============================================================================
/// Sign-in cannot work with a "default" client ID the way a normal package
/// import does — Google and Microsoft both require *you* (the app's owner)
/// to register the app in your own developer console and get back a client
/// ID that's tied to your bundle ID / package name / redirect URI. There is
/// no working credential can be filled in on someone else's behalf.
///
/// To make sign-in actually work:
///
/// GOOGLE:
///   Create a Web OAuth client and pass its ID as PETAL_GOOGLE_CLIENT_ID.
///   Android also needs an Android OAuth client with package + signing SHA-1.
///   iOS/macOS need their own OAuth clients and Info.plist configuration.
///   The google_sign_in plugin does not implement Windows/Linux.
///
/// MICROSOFT:
///   Register `petalauth://auth` under Mobile and desktop applications
///   for native builds, and the exact origin/path `/auth.html` under
///   Single-page application for each web deployment. Pass the Application
///   (client) ID as PETAL_MICROSOFT_CLIENT_ID. No client secret belongs in
///   this app. See the README's Sign-in setup section for full instructions.
///
/// Until you do this, the sign-in buttons will surface a clear error
/// instead of silently pretending to work.
library;

class AuthConfig {
  // Shared Web client ID for browser sign-in and Android serverClientId.
  static const googleWebClientId = String.fromEnvironment(
    'PETAL_GOOGLE_CLIENT_ID',
    defaultValue: 'YOUR_GOOGLE_OAUTH_CLIENT_ID.apps.googleusercontent.com',
  );

  static const microsoftClientId = String.fromEnvironment(
    'PETAL_MICROSOFT_CLIENT_ID',
    defaultValue: 'YOUR_MICROSOFT_APPLICATION_CLIENT_ID',
  );
  static const microsoftTenant = String.fromEnvironment(
    'PETAL_MICROSOFT_TENANT',
    defaultValue: 'common',
  );
  static const microsoftRedirectUri = String.fromEnvironment(
    'PETAL_MICROSOFT_REDIRECT_URI',
    defaultValue: 'petalauth://auth',
  );
  static const microsoftScopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
    'Files.Read',
    'Files.ReadWrite.AppFolder',
  ];

  static bool get googleConfigured => !googleWebClientId.startsWith('YOUR_');
  static bool get microsoftConfigured => !microsoftClientId.startsWith('YOUR_');
}
