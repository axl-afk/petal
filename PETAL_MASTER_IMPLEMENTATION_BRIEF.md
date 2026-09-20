# Petal — Master Implementation Brief

This document is the source of truth for the Petal rebuild. Every change must preserve the working six-platform Flutter build while moving the product toward the acceptance criteria below.

## Product promise

Petal is a fast, elegant music player for Android, iOS, macOS, Windows, Linux, and web. It presents local and cloud music as one library. A person can:

1. Play audio already available to the device.
2. Sign in with Google or Microsoft and explicitly grant read access to Google Drive or OneDrive.
3. Discover supported audio in the selected cloud account, stream it, or download it for offline playback.
4. Sign in on another device and recover the same cloud library, favorites, playlists, and playback preferences without copying every song to every device.

The visual character is calm, premium, and recognizably Petal: layered translucent surfaces, restrained color, depth, soft blur, fluid motion, strong typography, and excellent behavior at phone, tablet, desktop, and large-desktop widths. Glass effects must remain readable and performant; they are not decoration at the cost of usability.

## Non-negotiable platform behavior

| Platform | Local discovery | Cloud playback | Offline downloads |
|---|---|---|---|
| Android | Media-library permission and device audio discovery, plus file/folder import | Google Drive and OneDrive | Private app storage |
| iOS | Document picker/import; iOS does not allow arbitrary whole-device filesystem scans | Google Drive and OneDrive | App Documents/Application Support |
| macOS | Music folder, chosen folders/files, and user-accessible volume scan | Google Drive and OneDrive | Application Support |
| Windows | Music folder, chosen folders/files, and user-accessible drive scan | Google Drive and OneDrive | Application Support |
| Linux | Music folder, chosen folders/files, and user-accessible mount scan | Google Drive and OneDrive | Application Support |
| Web | Browser-selected files only when supported; never claim whole-device access | Google Drive and OneDrive | Browser storage only when explicitly supported; otherwise stream |

Never pretend to bypass an operating-system sandbox. When a platform cannot scan globally, use the native picker and explain the limitation in one sentence.

## Functional acceptance criteria

### Unified library and playback

- A single indexed library contains local, Google Drive, OneDrive, and direct-link tracks.
- Duplicate imports are idempotent and preserve favorites, lyrics, and playlist membership.
- Playback supports queue, previous/next, seek, shuffle, repeat, volume, speed, and graceful recovery from expired cloud URLs.
- Cloud playback obtains an authenticated stream URL/header at play time; access tokens and temporary URLs are not stored permanently.
- Local/offline files take precedence when available.
- Background audio, lock-screen controls, media keys, Bluetooth controls, and audio interruption handling are wired on supported platforms.

### Accounts and cloud libraries

- Google and Microsoft OAuth use PKCE/system browser where applicable, least-privilege scopes, state validation, and platform-specific redirect URIs.
- Client IDs come from build-time configuration; no secrets or user tokens are committed.
- Google Drive and Microsoft Graph scanners page through results, filter known audio formats/MIME types, support user cancellation, expose progress, and upsert in batches.
- A user may disconnect a provider and choose whether to keep its offline files.
- Authentication failure, revoked consent, rate limiting, offline state, and partial scans produce actionable UI rather than silent failure.

### Cross-device sync

- Sync stores portable metadata only: provider item IDs, metadata, favorites, playlists, tombstones, and update timestamps.
- Audio bytes remain in the user's own cloud or on the current device.
- Merge is deterministic and deletion-aware; newer field timestamps win and tombstones prevent deleted items from reappearing.
- Sync is scoped by provider account identity and never leaks one signed-in account's library to another user on a shared device.
- Sync runs after sign-in, after portable mutations with debounce, on manual request, and when the app resumes if stale.

### Offline downloads

- Cloud tracks can be downloaded, cancelled, retried, removed, and played without a network.
- Download state is persistent: not downloaded, queued, downloading, downloaded, failed.
- Writes use a temporary file followed by an atomic rename and verify non-empty content.
- The UI displays progress and storage usage, and never reports an incomplete file as available offline.

### Design and accessibility

- Responsive navigation: bottom navigation on phones, compact rail on tablets/small desktop, full sidebar on desktop.
- Now Playing is immersive but keeps controls reachable with one hand on phones.
- Transitions use shared-axis/fade/scale motion with reduced-motion support.
- Frosted surfaces have opaque fallbacks when blur is expensive or unsupported.
- Every action has semantics, keyboard focus, tooltips where appropriate, 44–48 px touch targets, WCAG-conscious contrast, and no information conveyed by color alone.
- Empty, loading, offline, permission-denied, and error states are designed states—not raw exceptions or blank screens.

## Architecture rules

- Keep UI, controllers, persistence, provider APIs, authentication, and file I/O separated.
- Use stable provider item IDs for identity; never use expiring stream URLs as primary keys.
- Store provider-neutral metadata in the database and resolve provider-specific playback/download requests through adapters.
- Keep secrets out of source. OAuth client IDs and redirect settings use `--dart-define`/CI environment configuration.
- Persist tokens only in OS secure storage. Never place access or refresh tokens in SharedPreferences, logs, sync snapshots, or database rows.
- Keep database migrations forward-only, tested, and safe for existing users.
- Batch database writes and keep heavy filesystem/metadata work off animation-critical paths.
- All network calls must have timeouts, bounded retries for transient failures, and useful typed errors.

## Delivery sequence

1. Establish a clean baseline: inspect CI, dependencies, schema, and tests.
2. Add provider-neutral cloud models/adapters and secure build-time auth configuration.
3. Implement paginated Google Drive and OneDrive discovery.
4. Add persistent offline-download state and downloader; prefer offline paths during playback.
5. Upgrade sync to a versioned deletion-aware merge model for both provider accounts.
6. Complete player behavior and platform media integration.
7. Rebuild the shell and screens with responsive frosted-glass design tokens and purposeful motion.
8. Add unit/widget tests for parsing, merge rules, download state, responsive behavior, and critical controllers.
9. Run formatting, generation, analysis, tests, and all-platform CI; fix every regression before release.

## Definition of done

- `flutter analyze` has no errors.
- Tests pass.
- GitHub Actions produces successful Android, iOS, macOS, Windows, Linux, and web artifacts.
- The app never claims a permission or capability the target OS does not provide.
- OAuth configuration still requires the repository owner to register provider applications and supply client IDs/redirect URIs; Petal must clearly detect and explain missing configuration.
- No tokens, credentials, or private user data are committed or logged.
- README setup and release instructions match the code exactly.

