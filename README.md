# Petal

A cross-platform music player (macOS, Windows, Linux, Android, iOS, and web)
that unifies device music, Google Drive, and OneDrive in one library, with
offline cloud downloads, cross-device metadata sync, and time-synced lyrics.

The current rebuild plan and acceptance criteria live in
[`PETAL_MASTER_IMPLEMENTATION_BRIEF.md`](PETAL_MASTER_IMPLEMENTATION_BRIEF.md).

### Current capabilities

- Android MediaStore discovery plus file/folder import on supported devices.
- Paginated Google Drive and OneDrive account scanning after explicit OAuth consent.
- Authenticated cloud streaming and persistent offline downloads.
- Portable favorites/playlists/library metadata stored in the user's own Google Drive app-data or OneDrive app folder—no Petal account server.
- Responsive phone/tablet/desktop navigation and layered frosted-glass surfaces.

OAuth client IDs are build-time configuration, not source-code secrets:

```bash
flutter run \
  --dart-define=PETAL_GOOGLE_CLIENT_ID=your-google-client-id \
  --dart-define=PETAL_MICROSOFT_CLIENT_ID=your-microsoft-client-id \
  --dart-define=PETAL_MICROSOFT_REDIRECT_URI=petalauth://auth
```

## License

Petal is licensed under **[CC BY-NC 4.0](LICENSE)** — free to use, modify,
and share, **for non-commercial purposes only**, as long as you credit the
original author and link back to this repo. Full terms are in
[`LICENSE`](LICENSE).

If you redistribute Petal or a modified version of it, include a credit
along these lines wherever you'd normally credit sources/dependencies:

> Based on [Petal](https://github.com/axl-afk/petal) by Samiul Islam,
> licensed under [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/).

## Please read this first — how this project was built

This code was written in a sandboxed environment that blocks outbound
network access to `storage.googleapis.com` and `pub.dev`. Those two hosts
are exactly what Flutter's own tooling needs to bootstrap itself and to
resolve packages — so **`flutter pub get`, `flutter analyze`, `flutter run`,
and `flutter build` could never be executed while this was written.**

That means every file here was hand-written to be correct and then checked
by hand — brace/paren balance across every Dart file, every Riverpod
provider and controller method cross-referenced against its definition,
every relative import verified to resolve to a real file, every widget
constructor checked against its call sites — but none of it has been
through a real Dart compiler. The very first thing to do on your own
machine is run `flutter pub get` and `flutter analyze` and fix whatever
they flag. Realistically expect a handful of small issues — a renamed API
in a package that moved past the version pinned here — rather than
structural problems; the architecture and logic were what mattered most to
get right by hand.

The riskiest single piece is the web database backend
(`lib/data/db/connection/web.dart`) — drift's web/wasm-sqlite API has
shifted across versions more than the rest of the package. If it doesn't
compile as-is, check the current shape at https://drift.simonbinder.eu/web/.

## Can I build an APK / iOS app / .exe / .pkg / .dmg / a web app on a VPS from this?

Yes, once the one-time setup below is done — and the most reliable way to
actually get those build artifacts is **not** this sandbox (which is
network-blocked) or necessarily your own machine either, but
**`.github/workflows/build.yml`**: push this repo to GitHub and it builds
all six targets — Android APK+AAB, an unsigned iOS .app, Windows .exe +
installer, macOS .app+.dmg+.pkg, Linux bundle+AppImage, and the web build —
on GitHub's own real, internet-connected runners, and hands you back
downloadable artifacts from the run's Summary page. That sidesteps this
project's authoring sandbox entirely, since GitHub's runners have no such
restriction.

### One-time setup (required before local builds *or* CI will work)

```bash
# 1. Dependencies
flutter pub get

# 2. drift's generated database code
dart run build_runner build --delete-conflicting-outputs
#    (a "--delete-conflicting-outputs ignored" warning on newer build_runner
#    versions is harmless — it became the default behavior; the command
#    still works, that flag is just a no-op now)

# 3. Platform runner folders — pick your own reverse-DNS org id here,
#    rather than leaving it as com.example, since Google Play / the App
#    Store both require a unique identifier you own
flutter create . --platforms=android,ios,macos,windows,linux,web --org=com.yourcompany

# 4. Real app icons (from assets/icon/, see pubspec.yaml's
#    flutter_launcher_icons config) into every platform's native format —
#    MUST run after step 3: it writes into android/, ios/, macos/, etc.,
#    which don't exist until `flutter create .` generates them
dart run flutter_launcher_icons
```

Then, **before your first real build**, apply the three snippets in
`packaging/` — these are platform config edits CI/local builds can't safely
guess for you:

- `packaging/android/AndroidManifest-snippet.xml` → merge into
  `android/app/src/main/AndroidManifest.xml` (local-file + Drive/OneDrive
  network permissions, and the URL-scheme intent-filter Microsoft sign-in's
  redirect needs).
- `packaging/ios-macos/Info-snippet.plist` → merge into **both**
  `ios/Runner/Info.plist` and `macos/Runner/Info.plist` (same URL-scheme
  requirement, for iOS and macOS).
- `packaging/macos/entitlements-snippet.plist` → merge into **both**
  `macos/Runner/DebugProfile.entitlements` and
  `macos/Runner/Release.entitlements` (macOS's App Sandbox otherwise
  silently blocks network calls and the local-file picker — a macOS-only
  gotcha, since no other platform sandboxes this way).
- iOS App Store review usage-description strings
  (`NSPhotoLibraryUsageDescription`/`NSAppleMusicUsageDescription`) into
  `ios/Runner/Info.plist` **only** (not macOS) — see the comment at the top
  of `packaging/ios-macos/Info-snippet.plist` for why these exist even
  though Petal never touches Photos or Apple Music.
- Android `compileSdk`/`targetSdk` bumped to 36, in **both**
  `android/app/build.gradle.kts` (the app module) **and** the root
  `android/build.gradle.kts` (forces the same version on every plugin
  subproject too — see `add_subprojects_compilesdk_override()`'s doc
  comment in the script for why both are needed).

You can do this by hand, or run the merge script that does all of it for
you:

```bash
python3 packaging/scripts/apply_packaging_snippets.py
```

It merges the plist-based files (`Info.plist` URL scheme x2, entitlements
x2, iOS usage descriptions x1) through Python's `plistlib`, so it can't
produce malformed XML, and does the Android manifest/Gradle edits as
guarded text insertions. It writes a `.orig` backup next to every file it
touches the first time, and it's safe to re-run — it detects what's
already applied and skips it. Diff the backups afterward if you want to
see exactly what changed, e.g.
`diff ios/Runner/Info.plist.orig ios/Runner/Info.plist`. Either way, double-check
the `CallbackActivity` class name it writes into the Android manifest
against your installed `flutter_web_auth_2` version before building — see
the comment in `packaging/android/AndroidManifest-snippet.xml` for why.

Two more dependencies (`window_manager`, `permission_handler`) were added
for the desktop min-window-size and Android permission-prompt features —
both are ordinary pure-Dart pub packages, so step 1 (`flutter pub get`)
already pulls them in; neither needs a packaging-script edit. The one
thing worth a quick check after `flutter create .`:
`permission_handler`'s own pub.dev page calls out needing
`android.useAndroidX=true` in `android/gradle.properties`, which every
current Flutter template already sets by default — only worth opening that
file if a build specifically complains about it.

Commit the generated `android/`, `ios/`, `macos/`, `windows/`, `linux/`,
`web/` folders once you've made these edits — they're deliberately **not**
in `.gitignore`. `.github/workflows/build.yml` builds from what's committed
rather than re-running `flutter create .` itself, specifically so it never
silently wipes these edits.

### Building each target locally

Building `linux` needs a few system libraries first (matches the packages
`.github/workflows/build.yml` installs on its runner — same names on
Debian/Ubuntu):

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libwebkit2gtk-4.1-dev
```

`libwebkit2gtk-4.1-dev` specifically is needed by `desktop_webview_window`,
a transitive dependency of `flutter_web_auth_2` — it's the embedded webview
Linux uses for the Microsoft sign-in flow, since Linux has no equivalent to
macOS/Windows' system-browser-callback approach. Skip it and `flutter build
linux` fails at the CMake step with "required packages were not found:
webkit2gtk-4.1".

```bash
flutter build apk --release          # Android — build/app/outputs/flutter-apk/
flutter build appbundle --release    # Android, for Play Store — .../bundle/release/
flutter build ios --release          # iOS — needs a Mac + Xcode + your Apple Developer signing
flutter build macos --release        # macOS .app — build/macos/Build/Products/Release/
flutter build windows --release      # Windows — build/windows/x64/runner/Release/
flutter build linux --release        # Linux — build/linux/x64/release/bundle/
flutter build web --release          # Web static site — build/web/
```

Raw `flutter build` output for macOS/Windows/Linux is a runnable
folder/`.app`, not a shareable installer. For an actual installer:

- **macOS → .dmg + .pkg**: `bash packaging/macos/build_dmg_pkg.sh` (also
  runs automatically in CI). Unsigned/unnotarized — fine to share directly
  or for internal testing; Gatekeeper will warn on other people's Macs
  until you sign with your own paid Apple Developer ID and notarize via
  `xcrun notarytool` — that step needs your own certificate and can't be
  pre-filled here.
- **Windows → installer .exe**: install Inno Setup, then
  `iscc packaging\windows\installer.iss` (also runs in CI). Unsigned —
  triggers a SmartScreen warning until you sign with your own code-signing
  certificate, same caveat as above.
- **Linux → .AppImage**: `bash packaging/linux/build_appimage.sh` (also
  runs in CI). For a `.deb` instead, `dpkg-deb` or `flutter_distributor`
  against the same `bundle/` folder is the more common route — not
  scripted here since `.deb` control-file metadata (maintainer, deps) is
  genuinely project-specific.
- **Web → a VPS**: `deploy/web/Dockerfile` + `deploy/web/nginx.conf` +
  `deploy/web/docker-compose.yml`. On the VPS:
  `docker compose -f deploy/web/docker-compose.yml up -d --build`, then
  point your existing reverse proxy / TLS setup at the container's port
  8080 (this repo doesn't presume to manage your certificates).

### Web build setup (extra step, before `flutter build web` specifically)

Drift's web backend needs two files copied into `web/` after step 4 above:
`sqlite3.wasm` (from the `sqlite3` package) and `drift_worker.js` (from
`drift`). The exact command has changed across drift releases — check
https://drift.simonbinder.eu/web/ for the current one. If `flutter run -d
chrome` fails specifically on opening the database, this is almost
certainly why.

### Sign-in setup (Google & Microsoft)

Sign-in is real OAuth code, but it can't function until *you* register the
app and paste in your own client ID — no working credential could be
supplied on your behalf; this isn't something that can be worked around,
since Google/Microsoft only issue a client ID to whoever registers the app
under their own developer account, tied to your specific bundle ID/package
name/redirect URI. Full instructions are in
`lib/data/services/auth/auth_config.dart` at the top of the file. Until you
do this, the sign-in buttons in Settings will show a clear "not configured"
message rather than pretending to work. Desktop (Windows/Linux) support in
`flutter_web_auth_2` specifically is worth double-checking against that
package's current docs before relying on it there — it's strongest on
iOS/Android/macOS/web.

**Fastest path to a real, testable sign-in — Google, web build:**
1. https://console.cloud.google.com/ → create/select a project.
2. APIs & Services → OAuth consent screen → External → fill in the app
   name/email → under Scopes, add `.../auth/userinfo.email`,
   `.../auth/userinfo.profile`, `https://www.googleapis.com/auth/drive.appdata`,
   and `https://www.googleapis.com/auth/drive.readonly` → under Test users,
   add your own Google account (keeps you off the "unverified app" block
   while testing). The last scope is a meaningfully bigger permission grant
   than the other three — see "Google Drive folder import" below for why
   it's needed and what it actually lets Petal see.
3. APIs & Services → Library → search "Google Drive API" → Enable (needed
   for the library backup feature to work at all).
4. APIs & Services → Credentials → Create Credentials → OAuth client ID →
   type **Web application** → add an Authorized JavaScript origin matching
   wherever you serve the build from (e.g. `http://localhost:8000` for the
   `python3 -m http.server 8000` local-test setup in "Web build setup"
   below) → Create.
5. Paste the resulting `....apps.googleusercontent.com` client ID into
   `googleWebClientId` in `auth_config.dart`.
6. If sign-in silently does nothing on web specifically (a known
   version-dependent quirk in `google_sign_in_web`), add
   `<meta name="google-signin-client_id" content="YOUR_CLIENT_ID">` inside
   `<head>` in the `web/index.html` that `flutter create .` generates —
   this wasn't verified against a real browser in this environment, so
   it's a "try this if it doesn't just work" note, not a guaranteed step.

Android/iOS/macOS need their own platform-specific registration (SHA-1
fingerprint, bundle ID, `GoogleService-Info.plist`) when you get to
building those — see the numbered checklist in `auth_config.dart` for the
full picture, including Microsoft's Azure App registration steps.

Note that sign-in's job in this app is narrower than it might sound: it
doesn't pull a file listing from Drive/OneDrive's API (that would need a
lot more plumbing). It authenticates your identity, and Petal uses that
identity to remember which Drive/OneDrive *links you've pasted* — so
signing in on a new device/reinstall re-resolves and reconnects those same
links automatically, matching "set up your drive links once, don't do it
again." Google sign-in specifically requests two extra scopes beyond
identity: the narrow `drive.appdata` (see the next section) and the
broader `drive.readonly` (see "Google Drive folder import" below).

## Google Drive folder import

Pasting a single song's share link has always worked as a plain URL
rewrite (see `LinkResolverService`) — no OAuth involved, works whether
you're signed in or not, same as before. Pasting a whole **folder** link
(`drive.google.com/drive/folders/...`) is different: listing what's
*inside* a folder isn't something a public URL can do, so it requires an
actual signed-in Google account and a real Drive API call
(`DriveFolderService.listAudioFiles`). Paste either shape into the same
box on Add Source — Petal tells them apart automatically
(`LinkResolverService.driveFolderId`) and imports every audio file found
directly inside the folder, skipping anything that isn't an audio
extension.

Two things worth knowing:
- **This is why the `drive.readonly` scope exists.** Listing folder
  contents needs read access to the parts of your actual Drive you choose
  to share this way — a meaningfully bigger ask than `drive.appdata`'s
  single hidden file. Declined that scope, or not signed in at all? Folder
  links fail with a clear message telling you to sign in first; single-file
  links are unaffected either way.
- **Subfolders aren't scanned (v1 scope)** — only files directly inside the
  folder you link. Move files up a level, or share the specific subfolder
  instead, if what you meant to import is nested.

## How library backup works (Google accounts only)

Petal doesn't run a server or a database of its own users — there's
nothing hosted for this at all. Instead, when you sign in with Google, the
app writes a small JSON file into a hidden, app-only folder inside *your
own* Google Drive (Drive's "Application Data" folder — invisible in your
normal Drive UI, and only Petal can read or write it; that's what the
`drive.appdata` OAuth scope grants, nothing broader than that one file).

What gets backed up: your saved Google Drive / OneDrive / direct links,
which of those are favorited, and any playlists built from them. What
doesn't: locally-imported files. Those exist as actual audio bytes only on
the device that imported them, so there's nothing meaningful to back up
beyond a phantom entry that couldn't play anywhere else anyway.

Sync happens automatically — right after you sign in (pulling back
anything already saved to this account, e.g. after a reinstall or on a new
device) and a few seconds after you add a link, toggle a favorite, or edit
a playlist while signed in. Settings shows the current backup status and a
manual "Sync now" button.

The sync model is intentionally simple, and it's worth knowing its shape:
each sync uploads this device's complete current state, and pulling only
ever adds/updates rows locally, never deletes. That means it's *not* a
true multi-device merge — if you remove a saved link or playlist on one
device, that removal won't be reflected on Drive or on another device that
syncs later; the entry will just keep coming back. In exchange, nothing is
ever silently lost, which felt like the better trade-off for a v1 than
building real multi-device conflict resolution.

Two more honest caveats: this is the single least-tested piece of the
whole project — it was written directly against the Drive API v3 reference
docs with no real Google account available in this environment to sign in
with and exercise it end-to-end (see `cloud_backup_service.dart`'s doc
comment), so if a sync fails with an error mentioning Drive or an HTTP
status code, paste it back. And `drive.appdata` is a "sensitive" scope on
Google's OAuth consent screen — until you verify your app in Google Cloud
Console, anyone who isn't added as a test user on your project will see an
"unverified app" warning when they try to sign in.

## Releasing a new version

This assumes the one-time setup above (`flutter create .`, packaging
snippets applied, platform folders committed) is already done and
`.github/workflows/build.yml` builds cleanly on a normal push to `main`.

**1. Get this code onto GitHub, if it isn't already:**

```bash
cd petal_src
git init                      # skip if this is already a git repo
git add -A
git commit -m "Petal v1"      # skip if you already have commits
gh repo create petal --public --source=. --remote=origin --push
# no gh CLI? create an empty repo on github.com instead, then:
#   git remote add origin https://github.com/<you>/petal.git
#   git branch -M main
#   git push -u origin main
```

**2. Confirm everything actually works before releasing anything:**
push (or `workflow_dispatch` from the Actions tab) and watch the **Build
Petal** workflow run. Six jobs build in parallel — android, web, windows,
macos, ios, linux. A green check on all six means every platform compiled
and produced a downloadable artifact on that run's Summary page; a red X
means the platform failed and the *next* step (attaching it to a public
Release) isn't safe to do yet for that platform specifically — open the
failed job's log and paste the error back rather than releasing around it.
`flutter analyze` and `flutter test` locally (if you have Flutter
installed on your own machine) catch most other issues faster than waiting
on CI.

**3. Tag a version to publish it as a public GitHub Release:**

```bash
git tag v1.0.0
git push origin v1.0.0
```

That tag push re-runs all six build jobs, then a seventh `release` job
downloads every platform's output, packages the ones that are a raw folder
(web, and a "portable" zip for windows/linux) into a single file each, and
publishes everything as a GitHub Release on your repo's Releases page —
`.apk`/`.aab` for Android, a `.zip` for web, `.exe` installer + a portable
`.zip` for Windows, `.dmg`/`.pkg` for macOS, a `.zip` of the simulator
`.app` for iOS, and an `.AppImage` + portable `.zip` for Linux. That
Release page's URL is the actual "someone downloads this and installs it"
link — share that, not the raw source repo. Push a new tag (`v1.0.1`, …)
for every future release; this workflow was written but not exercised
against a real GitHub Actions run in this environment, so treat the first
tag push as a real test and paste back anything the `release` job's log
complains about.

**What "ready to go with login" means in practice.** The APK/exe/dmg/etc.
this produces are genuinely installable and will run — but Google/Microsoft
sign-in only works for real end users once *you've* completed two things
that can't be automated or filled in on your behalf (see "Sign-in setup"
above): your own OAuth client ID pasted into `auth_config.dart`, and —
specifically for a *public* release, not just yourself testing — clicking
"Publish app" on Google's OAuth consent screen (or getting it verified, if
you kept the sensitive Drive scopes, which this app does). Skip that
second part and every user besides the test accounts you listed will hit
an "unverified app" block, not a working sign-in button.

**Beyond GitHub Releases** — actual app store listings (Google Play, Apple
App Store, Microsoft Store) get you discoverability and auto-updates, but
each is its own separate, longer process this workflow doesn't attempt:
Play Store needs a $25 one-time Play Console account, an upload keystore
you generate and keep forever (losing it means you can never update that
app listing again), and — as of the Play Console's current policy — a
target API level of Android 16 (API 36) for new submissions. The App Store
needs the $99/year Apple Developer Program (free Apple IDs can build and
run on your own devices via Xcode, but can't distribute through TestFlight
or the App Store), a real Development Team ID wired into Xcode signing
(replacing this workflow's `--simulator`-only iOS build), and App Store
Connect review. Unsigned Windows/macOS builds will show a SmartScreen/
Gatekeeper warning on first launch until you buy and wire in your own code-
signing certificate (Windows) or Apple Developer ID + notarization (macOS)
— annoying but not broken; users can click through it. None of this is set
up in this project, and none of it can be, without accounts and
credentials only you can create.

## Architecture

```
lib/
  main.dart, app.dart          — bootstrap, MaterialApp, theming
  theme/                       — design tokens ported from the approved
                                  HTML mockup: monochrome light/dark, no
                                  user-selectable accent color
  data/
    db/                        — drift (SQLite) schema: tracks, playlists,
                                  playlist_tracks, saved_sources; an FTS5
                                  virtual table + sync triggers for real
                                  full-text search; explicit indices on
                                  every column the DAOs filter/group by
                                  (see app_database.dart)
    models/                    — small plain-Dart models that don't belong
                                  in the database (lyric lines, auth session,
                                  link-resolution results)
    services/                  — link_resolver_service (Drive/OneDrive share
                                  link -> direct stream URL), lyrics_service
                                  (lrclib.net client + LRC parser — fetched
                                  automatically the moment a track starts
                                  playing and cached to that track's row,
                                  see PlaybackController._loadLyricsFor),
                                  auth/ (Google + Microsoft OAuth),
                                  local_file_service, window/window_service
                                  (desktop minimum window size + fullscreen
                                  rebuild nudge, no-op on mobile/web)
  state/                       — Riverpod controllers: playback (wraps
                                  just_audio), library (search/filter/CRUD
                                  over the database), auth, theme, nav,
                                  onboarding (first-run gate)
  ui/
    shell/                     — responsive app shell: top bar, side rail,
                                  right rail, mini player
    screens/                   — Onboarding, Library, Now Playing, Lyrics,
                                  Add Source, Settings
    widgets/                   — track table (a lazy SliverList, not an
                                  eagerly-built Column — see "Efficiency"
                                  below), waveform seek bar (a CustomPainter,
                                  not per-bar widgets), hero banner, grid
                                  cards, swipe_down_to_dismiss (drag-to-fold
                                  gesture used by Now Playing and Lyrics)
packaging/                     — per-platform installer configs + the
                                  manifest/plist/entitlements snippets above
deploy/web/                    — Docker + nginx config for hosting the web
                                  build on a VPS
.github/workflows/build.yml    — CI: builds all six targets on GitHub's
                                  runners
```

## Efficiency & data-structure notes

A few decisions were made specifically so this stays smooth as a real
library (thousands of tracks) grows, not just with the handful of demo
tracks a first run has:

- **FTS5, not a LIKE scan.** The Library search box queries the `tracks_fts`
  virtual table (tokenized, prefix-matched, ranked) rather than scanning
  every row with `LIKE '%query%'`, which can't use an index at all.
- **Explicit indices** on `tracks(artist)`, `tracks(genre)`,
  `tracks(is_favorite)`, `tracks(owner_account)`,
  `playlist_tracks(track_id)`, and `saved_sources(account_email)` — every
  column a DAO actually filters or groups by (see `track_dao.dart` /
  `source_dao.dart`), so those queries hit an index instead of a full scan.
- **WAL journal mode**, set in `AppDatabase.migration.beforeOpen` — lets the
  FTS sync triggers (writes) and the Library screen's reactive stream
  queries (reads) proceed without blocking each other, which is what keeps
  Riverpod's "watch a query, rebuild on change" pattern smooth under real
  use instead of stuttering on every insert.
- **Lazy list rendering.** `TrackTable` is a `SliverList` with a builder
  delegate, and the Artist/Genre/Playlist grids use `GridView.builder` —
  both build only the rows/cards near the viewport. Earlier drafts of this
  screen used a plain `Column`/`GridView.count`, which builds *every* row
  up front regardless of scroll position; fine for a demo library, not fine
  once someone has a few thousand tracks.
- **Position updates don't touch app-wide state.** `PlaybackState`
  (Riverpod) deliberately excludes playback position/duration — those tick
  many times a second and would rebuild the whole Library/Now Playing tree
  if they lived there. Widgets that need them (the waveform seek bar, the
  mini player's progress bar) subscribe to `player.positionStream`
  directly via a narrowly-scoped `StreamBuilder` instead.
- **Background-isolate native database.** `NativeDatabase.createInBackground`
  (see `connection/native.dart`) runs SQLite on its own isolate so a large
  query never blocks a frame on desktop/mobile.
- **The waveform is one `CustomPainter`**, not dozens of individually
  animated bar widgets — it repaints as a single draw call keyed off
  `progress`, so it doesn't fight the framework's layout pass on every
  position tick the way a `Row` of `AnimatedContainer`s would.

A follow-up review, focused specifically on search correctness and
efficiency, found and fixed a few more:

- **Search is reactive now, not a one-shot query.** `TrackDao.search()` used
  to be a plain `Future<List<Track>>` wrapped in `.asStream()` at the call
  site — it ran once and never updated again, so favoriting a track,
  re-scanning a folder, or any other DB write made while search results
  were on screen silently went stale (the data was right, the visible list
  just wasn't). It's now a real `.watch()`-backed `Stream`, same as every
  other list query in the DAO, with the LIKE fallback path (used only if
  FTS5 itself errors) properly escaping the SQL `_` wildcard too, not just
  `%`.
- **Search input is debounced** (`LibraryController.setSearchQuery`, 300ms)
  instead of re-running the DB query on every keystroke — the typed text
  still appears instantly (the search field isn't bound to this state), but
  the actual query now waits for a short pause in typing. Switching tabs or
  filters cancels any pending debounce, so a stale search can't overwrite a
  filter change made while it was waiting.
- **No more full-screen spinner flicker while searching or filtering.** The
  Library screen's track list now passes `skipLoadingOnReload: true` to its
  `AsyncValue.when()`, so the previous results stay visible while a new
  query is in flight instead of being replaced by a spinner and popping
  back — this was especially visible once search became reactive, since
  every settled keystroke re-subscribed to a new stream.
- **Bulk imports are one transaction, not hundreds of tiny ones.**
  `TrackDao.upsertAll()` (used by every local file/folder import) now wraps
  its whole batch in a single `transaction()` — faster (one commit instead
  of one per track), and if something throws partway through a large
  import, the batch rolls back cleanly instead of leaving the library with
  only some of that scan's tracks and no way to tell which.
- **The FTS sync trigger only fires on columns that matter.** `tracks_au`
  used to run on *every* update to a track row — including favoriting and
  lyrics caching, the two most frequent writes in the app, neither of which
  touches a searchable field. It's now scoped to
  `AFTER UPDATE OF title, artist, album, genre`, with a real schema
  migration (`schemaVersion` 1 → 2) so it also applies retroactively to a
  database created before this fix, not just fresh installs.

## Security

A dedicated security pass over how account data is stored and scoped
found and fixed a few real issues, on top of what "Sign-in setup" already
covers about credentials:

- **Signing out now actually clears that account's data from the device.**
  Local reads were never scoped by account — on a shared device, whoever
  opened Petal next (signed out, or signed in as someone else) could still
  see and play everything the previous Google/Microsoft account had added.
  `AuthController.signOut` now deletes that account's tracks
  (`TrackDao.deleteForAccount`) before clearing the session. Safe to delete:
  Google accounts restore it from their Drive backup on next sign-in;
  Microsoft accounts re-resolve it from `SavedSources` (kept, not deleted).
  Purely local file imports (no owning account) are never touched.
- **The link resolver only accepts `http`/`https` now.** A pasted link
  reaching the audio player with an unexpected URI scheme was never
  filtered before — now anything else is rejected with a clear error before
  it gets anywhere near playback.
- **OAuth access/refresh tokens are no longer persisted to disk.** Nothing
  in the app ever read them back from storage (Google's token is always
  freshly re-derived via silent re-auth; there's no Microsoft refresh flow
  at all), so writing them into `shared_preferences` — unencrypted on every
  platform this app ships to — was pure exposure with no functional
  benefit. They still exist as in-memory fields for the current run; a
  reloaded session now always comes back with both `null`.
- **Embedded artwork is capped at 8MB per file** before being written to
  disk, so a malformed or hostile audio tag can't be used to balloon local
  storage use during an import.
- **The web deploy's nginx config now sends real security headers** —
  Content-Security-Policy, `X-Content-Type-Options: nosniff`,
  `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy`, and a `Permissions-Policy`
  — see the comments in `deploy/web/nginx.conf` for exactly what the CSP
  allows and why (it has to leave room for the Google Sign-In web flow and
  direct Drive API calls). Not independently verified against a live
  deploy from this environment — if sign-in or Drive folder import breaks
  only on the web build after deploying this, the browser console will show
  a CSP violation naming the exact directive to loosen.

## Known limitations (v1, honestly noted rather than silently shipped)

- **A pasted single-file Google Drive link with no typed title** now shows
  the file's real Drive name automatically — but only when you're signed
  in with Google (the lookup needs a Drive API call, same as folder import
  already required). Signed out, or if the lookup fails for any reason
  (offline, revoked access), it still falls back to "Untitled Track" as
  before — type a title yourself in that case, or sign in first. Drive
  doesn't expose a song's artist, duration, or album at all (that's not
  file metadata Drive tracks), so those still show as "Unknown Artist" and
  blank until the track is actually played, matching how it always worked
  for OneDrive/direct links, which have no equivalent lookup at all — a
  background duration probe (loading just enough of the stream to read
  it before you ever hit play) is a real option but wasn't added here, to
  avoid shipping an untested async mechanism that's hard to verify without
  a real account to test against.
- **Desktop window has a minimum size (380×560)** — `window_manager` sets
  this at startup (`WindowService.ensureInitialized()`, called from
  `main()`), so the window can no longer be resized/"folded" down to
  something the shell can't actually render legibly. No-op on Android/iOS/
  web. If 380×560 feels wrong for your content once you can actually see it
  running, it's one constant to change
  (`lib/data/services/window/window_service_io.dart`).
- **macOS native-fullscreen layout** — added a `window_manager`
  `WindowListener` that nudges a rebuild on fullscreen enter/exit and
  resize, as insurance for the reported "UI doesn't recenter in fullscreen"
  issue. Verified against Flutter's own macOS embedder source that window-
  metric propagation on fullscreen transitions works the same as any other
  resize (not a known engine bug), and nothing in this app's layout code
  caches a stale size — so this is a defensive addition rather than a
  confirmed root-cause fix; if fullscreen still looks wrong after this,
  paste back what you're seeing (ideally a screenshot) so it can be
  diagnosed against the real behavior instead of guessed at again.
- **Mobile "slide the player down to fold it" gesture** — dragging Now
  Playing (or Lyrics) down past ~120px now does the same thing the
  existing down-arrow button already did (folds back to the mini player +
  whatever section was showing underneath), just with the content
  following the drag instead of an instant jump. See
  `ui/widgets/swipe_down_to_dismiss.dart` — distance-only, no fling/
  velocity shortcut, since both screens are fixed non-scrolling layouts
  with no competing scroll gesture to fight.
- **First-run screen now asks to sign in or "just play music on this
  device"**, and on Android shows a real permission request for audio-file
  access. That Android permission is *not* required by anything Petal does
  today — verified against `file_picker`'s own manifest/changelog that its
  Android (Storage Access Framework) and iOS (system document picker) flows
  both already work with zero runtime permission grants, so declining it
  doesn't break importing music at all. It's there for two honest reasons:
  the product explicitly wants that first-run moment, and it's real,
  working plumbing for a future on-device library scan (the phone
  equivalent of "Scan whole computer," not implemented yet — see below).
  iOS shows no permission button, since none exists to request; the screen
  says so instead of faking one.
- **Playlist/library track rows now show album art** (or the same
  placeholder icon Mini Player and Now Playing already used) — they simply
  never rendered any artwork/icon before, unlike every other place a track
  appears in the app.
- **Very large Google Drive files**: Drive's "can't scan this file for
  viruses" interstitial (triggered above a certain file size) needs a
  `confirm=` token that isn't handled yet. Typical audio file sizes work
  fine with the direct `uc?export=download` URL.
- **Local file metadata & artwork come from real tags**: title, artist,
  album, genre, duration, and cover art are read from embedded ID3/MP4/FLAC
  tags via the `audio_metadata_reader` package — pure Dart, no native/FFI
  bridge. This project originally used `audiotags` instead, which turned
  out to have a real, long-open, maintainer-unresponsive bug that broke
  every macOS and iOS build (github.com/erikas-taroza/audiotags issues
  #14/#21/#34 — its bundled native library was compiled against a different
  `flutter_rust_bridge` ABI version than the header it ships, so a handful
  of bridge symbols like `_wire_read`/`_new_box_autoadd_*` were always
  undefined at link time, on any architecture). Switching to a pure-Dart
  package removes that whole failure class rather than working around it.
  If a file has no tags at all, or `audio_metadata_reader` can't parse it,
  Petal falls back to a filename-derived title and the plain placeholder
  icon rather than failing the import.
- **Imported local files are copied, not linked**: picking a file (or
  scanning a folder) copies it into Petal's own app-support storage rather
  than just remembering the original path. This roughly doubles disk usage
  for your imported library, but it's what makes playback survive an app
  restart — macOS in particular revokes a picked file's read permission
  once the app quits unless you implement security-scoped bookmarks, which
  this version doesn't. Ask if you'd rather have bookmarks instead of the
  copy (no extra disk use, more moving parts).
- **Two desktop scan options, one deliberately fast and narrow, one
  deliberately thorough and slow**: "Scan Music folder" checks just
  `~/Music` (or the Windows/Linux equivalent), recursively — the quick
  common-case option. "Scan whole computer" is a real whole-disk crawl
  (every drive/volume the OS exposes), skipping hidden directories and
  OS-owned locations that are either permission-denied for a normal user
  anyway or never contain personal music (`Windows/Program Files`,
  `macOS/System`+`Library`, `Linux/proc`+`sys`+`dev`, plus generic noise
  like `node_modules`/`.git`/`.cache`) — see `scanWholeComputer` in
  `local_file_service_io.dart`. Neither button appears on Android/iOS: most
  audio there lives behind MediaStore (Android) or the Photos-library-style
  picker (iOS), not a plain accessible filesystem path the way desktop
  files are, so a "scan the whole phone" feature needs a real
  platform-integration package (e.g. `on_audio_query` on Android) — not
  attempted yet, specifically so as not to repeat the exact mistake that
  caused this session's `audiotags` build failures: guessing at a native
  package's API instead of verifying it first.
- **Responsive scaling is a first pass, not exhaustive**: the layout now
  reads the window width and scales up text (app-wide) plus the
  highest-impact fixed dimensions — side rail, right rail, and top bar
  sizes, and artwork placeholders — on wide/4K screens. It does not yet
  rescale every literal pixel value across every screen; if a specific
  screen still looks cramped at your resolution, point it out and it can
  get the same treatment.
- **Microsoft sign-out** only clears Petal's local session — it doesn't hit
  Microsoft's `/logout` endpoint to end the browser SSO session, which is
  normal for a native/desktop OAuth flow but worth knowing.
- **1drv.ms short links** are passed straight to the player rather than
  pre-resolved, relying on the HTTP client to follow the redirect.
- **Installers are unsigned** (see the packaging section above) — expected
  Gatekeeper/SmartScreen warnings until you add your own certificates.
- **Google/Microsoft sign-in and Drive/OneDrive linking need real OAuth
  credentials and, on macOS, the packaging snippets applied** (see
  "Sign-in setup" above and `packaging/scripts/apply_packaging_snippets.py`).
  Without both, sign-in fails — and now that failure shows as a visible red
  error banner instead of silently doing nothing.
- **Google Drive library backup is Google-only, not a true multi-device
  merge, and the least-tested integration in the project** — see "How
  library backup works" above for the full picture (what syncs, what
  doesn't, and the "last full state pushed wins, no deletion propagation"
  model). Microsoft/OneDrive accounts don't get this yet; a similar
  mechanism exists on Microsoft Graph (an "approot" special folder,
  conceptually identical to Drive's `appDataFolder`) if you want it added.
- **Google Drive folder import doesn't recurse into subfolders** — see
  "Google Drive folder import" above.
- **CI build failures were fixed as real build outputs came back from real
  runners** — this project has never had its own working Flutter/Xcode/
  Gradle toolchain available in the environment it was authored in, so
  every one of these was diagnosed from pasted CI logs, not reproduced and
  re-verified locally. Paste back the resulting log if any of these doesn't
  fully resolve it:
  - **Android — two separate compileSdk failures, now both fixed**:
    `flutter build apk` first failed at `:audiotags:checkReleaseAarMetadata`
    because the generated project compiled against android-31 — modern
    AndroidX libraries commonly require compileSdk 34+ now. After bumping
    that, a *second*, different failure showed up:
    `:file_picker:checkReleaseAarMetadata` — `flutter_plugin_android_lifecycle`
    (a dependency of the file_picker plugin) requires compileSdk 36+, while
    file_picker itself was still compiling against android-34. The reason
    the first fix didn't also cover this: every Flutter plugin subproject
    (file_picker, flutter_plugin_android_lifecycle, etc.) resolves its own
    compileSdk independently, via its own private copy of Flutter's
    `flutter` Gradle extension — patching only the app module's
    `android/app/build.gradle.kts` never touches what a plugin module
    itself compiles against. `packaging/scripts/apply_packaging_snippets.py`
    now fixes both: it sets `compileSdk`/`targetSdk` to 36 in
    `android/app/build.gradle(.kts)` (the app module) **and** adds a
    root-level `subprojects { afterEvaluate { ... compileSdkVersion(36) } }`
    block to `android/build.gradle(.kts)` (the project root) that forces
    compileSdk 36 on every subproject uniformly — app and every plugin
    alike, regardless of what each individually declares. Both edits match
    Google Play Console's own current target API level requirement, not
    just "high enough for today's plugins." — **if you already ran that
    script before this fix existed, re-run it** (safe — it's idempotent)
    and re-commit BOTH the generated `android/app/build.gradle(.kts)` AND
    the root `android/build.gradle(.kts)`, or CI will keep hitting one of
    these two errors.
  - **macOS / iOS**: see the `audio_metadata_reader` note above — the
    undefined-symbol linker failures on both platforms were `audiotags`,
    not this project's code or CI config, and are gone now that it's been
    replaced. The macOS job also no longer restricts the build to
    Apple Silicon — that restriction was a workaround for a
    misdiagnosis (see the note above) and has been removed, so macOS builds
    universal (arm64+x86_64) again.
  - **iOS signing**: separately from the above, `flutter build ios --release
    --no-codesign` still fails with "requires a Development Team" on its
    own, because it targets a real device, which Apple always requires
    signing for even with `--no-codesign`. CI builds for the simulator
    instead (`--simulator`, uploaded as `petal-ios-simulator-unsigned`) —
    good for verifying the app builds and runs, not something you can
    install on a physical iPhone. A real device build needs your own Apple
    Developer Team ID wired into Xcode signing.
  - **Windows**: `flutter build windows` failed extracting a plugin's
    CMake package because the runner didn't have symlink privileges. CI now
    sets the `AllowDevelopmentWithoutDevLicense` registry key (the headless
    equivalent of turning on Developer Mode) before building.
  - **Linux AppImage packaging**: `appimagetool` (itself distributed as an
    AppImage) failed with "AppImages require FUSE to run" — GitHub's
    `ubuntu-latest` runner (Ubuntu 24.04) doesn't preinstall FUSE, and the
    package that provides it was renamed (`libfuse2` → `libfuse2t64`) in
    24.04, so the commonly-cited `apt-get install libfuse2` fix doesn't even
    apply there anymore. `build_appimage.sh` now sets
    `APPIMAGE_EXTRACT_AND_RUN=1` instead, which makes appimagetool
    self-extract and run without needing FUSE at all — sidesteps the
    package-name churn entirely rather than chasing it.

## What each package is doing here

`flutter_riverpod` (state), `drift` + `sqlite3_flutter_libs` (database),
`just_audio` + `just_audio_web` + `audio_session` (playback), `file_picker`
(local import, gated off on web), `audio_metadata_reader` (pure-Dart —
reads embedded title/artist/album/genre/duration/cover-art tags from
imported local files; replaced `audiotags` after that package's native
library turned out to have a real, unresolved macOS/iOS linking bug — see
"Known limitations" above), `crypto` (OAuth state, hashing a local file's
path or a pasted cloud link
into a stable library ID so re-importing/re-pasting the same thing updates
it instead of duplicating it, and the deterministic ids that Google Drive
library backup keys off of), `google_sign_in` + `flutter_web_auth_2`
(OAuth — `google_sign_in` also carries the extra `drive.appdata` scope
that library backup runs on), `http` (lyrics + link handling, and the raw
Drive REST API calls in `cloud_backup_service.dart` — the least
battle-tested *code* here), `shared_preferences` (session/theme/onboarded-
flag only — library data always lives in the database),
`flutter_launcher_icons` (generates real per-platform icons from
`assets/icon/`), `window_manager` (desktop-only — minimum window size +
fullscreen-transition listener, see "Known limitations"), `permission_handler`
(Android-only — the first-run audio-access request; not needed by
`file_picker` itself, see "Known limitations" for why it's here anyway).
