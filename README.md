# Petal

A cross-platform music player (macOS, Windows, Linux, Android, iOS, and web)
that plays local files or pasted Google Drive / OneDrive share links, with
real time-synced lyrics.

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

You can do this by hand, or run the merge script that does all five edits
for you:

```bash
python3 packaging/scripts/apply_packaging_snippets.py
```

It merges the plist-based files (`Info.plist` x2, entitlements x2) through
Python's `plistlib`, so it can't produce malformed XML, and does the
Android manifest edit as a guarded text insertion. It writes a `.orig`
backup next to every file it touches the first time, and it's safe to
re-run — it detects what's already applied and skips it. Diff the backups
afterward if you want to see exactly what changed, e.g.
`diff ios/Runner/Info.plist.orig ios/Runner/Info.plist`. Either way, double-check
the `CallbackActivity` class name it writes into the Android manifest
against your installed `flutter_web_auth_2` version before building — see
the comment in `packaging/android/AndroidManifest-snippet.xml` for why.

Commit the generated `android/`, `ios/`, `macos/`, `windows/`, `linux/`,
`web/` folders once you've made these edits — they're deliberately **not**
in `.gitignore`. `.github/workflows/build.yml` builds from what's committed
rather than re-running `flutter create .` itself, specifically so it never
silently wipes these edits.

### Building each target locally

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
supplied on your behalf. Full instructions are in
`lib/data/services/auth/auth_config.dart` at the top of the file. Until you
do this, the sign-in buttons in Settings will show a clear "not configured"
message rather than pretending to work. Desktop (Windows/Linux) support in
`flutter_web_auth_2` specifically is worth double-checking against that
package's current docs before relying on it there — it's strongest on
iOS/Android/macOS/web.

Note that sign-in's job in this app is narrower than it might sound: it
doesn't pull a file listing from Drive/OneDrive's API (that would need
extra scopes and a lot more plumbing). It authenticates your identity, and
Petal uses that identity to remember which Drive/OneDrive *links you've
pasted* — so signing in on a new device/reinstall re-resolves and
reconnects those same links automatically, matching "set up your drive
links once, don't do it again."

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
                                  (lrclib.net client + LRC parser), auth/
                                  (Google + Microsoft OAuth), local_file_service
  state/                       — Riverpod controllers: playback (wraps
                                  just_audio), library (search/filter/CRUD
                                  over the database), auth, theme, nav
  ui/
    shell/                     — responsive app shell: top bar, side rail,
                                  right rail, mini player
    screens/                   — Library, Now Playing, Lyrics, Add Source,
                                  Settings
    widgets/                   — track table (a lazy SliverList, not an
                                  eagerly-built Column — see "Efficiency"
                                  below), waveform seek bar (a CustomPainter,
                                  not per-bar widgets), hero banner, grid cards
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

## Known limitations (v1, honestly noted rather than silently shipped)

- **Very large Google Drive files**: Drive's "can't scan this file for
  viruses" interstitial (triggered above a certain file size) needs a
  `confirm=` token that isn't handled yet. Typical audio file sizes work
  fine with the direct `uc?export=download` URL.
- **Local file metadata**: title comes from the filename, not real ID3/MP4
  tags. Adding a tag-reading package (e.g. `audiotags`) is a clean follow-up.
- **No artwork fetching/rendering yet**: the schema has an `artworkUrl`
  column and the UI has a placeholder icon slot ready for it, but nothing
  populates or renders real album art yet.
- **Microsoft sign-out** only clears Petal's local session — it doesn't hit
  Microsoft's `/logout` endpoint to end the browser SSO session, which is
  normal for a native/desktop OAuth flow but worth knowing.
- **1drv.ms short links** are passed straight to the player rather than
  pre-resolved, relying on the HTTP client to follow the redirect.
- **Installers are unsigned** (see the packaging section above) — expected
  Gatekeeper/SmartScreen warnings until you add your own certificates.

## What each package is doing here

`flutter_riverpod` (state), `drift` + `sqlite3_flutter_libs` (database),
`just_audio` + `just_audio_web` + `audio_session` (playback), `file_picker`
(local import, gated off on web), `google_sign_in` + `flutter_web_auth_2`
+ `crypto` (OAuth), `http` (lyrics + link handling), `shared_preferences`
(session/theme only — library data always lives in the database),
`flutter_launcher_icons` (generates real per-platform icons from
`assets/icon/`).
