/// ============================================================================
/// PLACEHOLDER OAUTH CREDENTIALS — READ BEFORE SHIPPING
/// ============================================================================
/// Sign-in cannot work with a "default" client ID the way a normal package
/// import does — Google and Microsoft both require *you* (the app's owner)
/// to register the app in your own developer console and get back a client
/// ID that's tied to your bundle ID / package name / redirect URI. There is
/// no working credential Claude could have filled in here on your behalf.
///
/// To make sign-in actually work:
///
/// GOOGLE:
///   1. https://console.cloud.google.com/ → new project → APIs & Services →
///      Credentials → Create OAuth client ID.
///   2. Create one client per platform you ship (Android needs your SHA-1
///      signing fingerprint, iOS needs your bundle ID, Web needs your
///      deployed origin).
///   3. Android/iOS: follow the google_sign_in package's platform setup
///      (google-services.json / GoogleService-Info.plist, or the
///      `serverClientId` param) — no client ID needs pasting here for
///      those two platforms.
///   4. Web/desktop: paste your Web client ID into [googleWebClientId] below.
///
/// MICROSOFT:
///   1. https://portal.azure.com/ → Azure Active Directory → App
///      registrations → New registration.
///   2. Add a "Mobile and desktop applications" / "Web" redirect URI
///      matching [microsoftRedirectUri] below (change the placeholder to
///      match your own registered app, e.g. `msauth.com.yourcompany.petal://auth`
///      on mobile, or a custom scheme on desktop).
///   3. Paste the Application (client) ID into [microsoftClientId].
///
/// Until you do this, the sign-in buttons will surface a clear error
/// instead of silently pretending to work.
library;

class AuthConfig {
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
