import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/auth_session.dart';
import '../../data/services/android_permissions.dart';
import '../../state/auth_controller.dart';
import '../../state/library_controller.dart';
import '../../state/onboarding_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/glass_surface.dart';

/// First-run screen: "sign in, or just play music already on this device"
/// (the product's own framing), plus — on Android — the explicit
/// "Petal would like access to your audio files" permission moment.
///
/// Why a real permission_handler request even though file_picker itself
/// doesn't need one: verified against file_picker's own manifest/changelog
/// that its Android (Storage Access Framework) and iOS (system document
/// picker) flows both work with zero runtime permission grants — so this
/// permission enables Petal's MediaStore scan, the Android equivalent of a
/// desktop music-folder scan. Declining it does not block file-picker imports.
/// iOS gets no equivalent button — verified
/// there's no runtime permission dialog for iOS's document picker at all,
/// so a fake "allow access" button there would just be theater; the iOS
/// copy says so plainly instead.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _requestingPermission = false;
  PermissionStatus? _permissionResult;
  bool? _notificationGranted;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _requestAudioAccess() async {
    setState(() => _requestingPermission = true);
    // Android 13+ (API 33) uses READ_MEDIA_AUDIO, which Permission.audio
    // maps to; older Android uses READ_EXTERNAL_STORAGE (Permission.storage
    // — capped at maxSdkVersion 32 in the manifest already, see
    // apply_packaging_snippets.py's PERMISSION_BLOCK). Verified this is
    // safe to call unconditionally: on an OS version where a given
    // permission group isn't applicable, .request() just resolves to
    // `denied` with no dialog shown, rather than throwing — so trying audio
    // first and falling back to storage covers both without needing a
    // separate package to detect the exact SDK level.
    final granted = await AndroidPermissions.requestAudioLibrary();
    if (!mounted) return;
    setState(() {
      _requestingPermission = false;
      _permissionResult = granted
          ? PermissionStatus.granted
          : PermissionStatus.denied;
    });
    if (granted) {
      try {
        await ref.read(libraryControllerProvider.notifier).scanDeviceMusic();
      } catch (_) {
        // Permission succeeded; a scan can still be retried from Add Source.
      }
    }
  }

  Future<void> _signIn(AuthProviderKind kind) async {
    await ref.read(authControllerProvider.notifier).signIn(kind);
    if (!mounted) return;
    if (ref.read(authControllerProvider).isSignedIn) {
      await ref.read(onboardingControllerProvider.notifier).complete();
    }
  }

  Future<void> _useLocalOnly() async {
    await ref.read(onboardingControllerProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: petal.colors.ground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 568),
              child: GlassSurface(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/icon/icon_square.png',
                        width: 72,
                        height: 72,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Petal',
                      style: petal.text.heroTitle.copyWith(fontSize: 28),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      label: 'Introduction step ${_step + 1} of 4',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          4,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 6,
                            width: index == _step ? 24 : 8,
                            decoration: BoxDecoration(
                              color: index == _step
                                  ? petal.colors.accent
                                  : petal.colors.ink3,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _buildStep(context, auth),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        if (_step > 0)
                          TextButton(
                            onPressed: () => setState(() => _step--),
                            child: const Text('Back'),
                          ),
                        const Spacer(),
                        if (_step < 3)
                          FilledButton(
                            onPressed: () => setState(() => _step++),
                            child: const Text('Next'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, AuthState auth) {
    final petal = context.petal;
    final heading = switch (_step) {
      0 => 'Your music, in one place',
      1 => 'Choose where music comes from',
      2 => 'Find your way around',
      _ => 'Make it yours',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          heading,
          style: petal.text.sectionTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        if (_step == 0) ...[
          const _InfoLine(
            icon: Icons.library_music_outlined,
            text:
                'Browse your songs, artists, albums, playlists and favorites.',
          ),
          const _InfoLine(
            icon: Icons.play_circle_outline,
            text: 'Play, seek, manage the queue and open a full-screen lyrics-only view.',
          ),
          const _InfoLine(
            icon: Icons.download_outlined,
            text: 'Save supported cloud tracks to listen offline.',
          ),
        ] else if (_step == 1) ...[
          if (_isAndroid) ...[
            const _InfoLine(
              icon: Icons.phone_android,
              text: 'Scan audio on this phone, or choose individual files.',
            ),
            _PermissionCard(
              granted: _permissionResult?.isGranted ?? false,
              denied:
                  _permissionResult != null && !_permissionResult!.isGranted,
              busy: _requestingPermission,
              onRequest: _requestAudioAccess,
            ),
            const SizedBox(height: 12),
            const _InfoLine(
              icon: Icons.notifications_active_outlined,
              text: 'Allow playback notifications for song controls outside Petal. Android may show the system request when you first play a song.',
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final granted = await AndroidPermissions.requestPlaybackNotifications();
                if (mounted) setState(() => _notificationGranted = granted);
              },
              icon: const Icon(Icons.notifications_outlined),
              label: Text(_notificationGranted == true
                  ? 'Playback notifications allowed'
                  : 'Allow playback notifications'),
            ),
          ] else if (_isIOS)
            const _InfoLine(
              icon: Icons.folder_open,
              text: 'Choose audio with the Files picker on iPhone or iPad. iOS and iPadOS do not offer whole-device scanning.',
            )
          else if (kIsWeb)
            const _InfoLine(
              icon: Icons.web,
              text: 'Connect cloud music. A browser cannot scan your device storage.',
            )
          else
            const _InfoLine(
              icon: Icons.folder_open,
              text: 'Choose files or folders, or scan your Music folder and accessible drives.',
            ),
          const _InfoLine(
            icon: Icons.cloud_outlined,
            text: 'Scan a connected cloud account, or paste a Google Drive folder link to import only that folder.',
          ),
        ] else if (_step == 2) ...[
          const _InfoLine(
            icon: Icons.add_circle_outline,
            text: 'Add Source imports local files, a selected folder, or a supported cloud link.',
          ),
          const _InfoLine(
            icon: Icons.library_music_outlined,
            text: 'Library groups your songs by album, artist, genre, playlist and favorites. Search finds your music.',
          ),
          const _InfoLine(
            icon: Icons.play_circle_outline,
            text: 'Tap a song to play. Open Now Playing for the queue, playback controls and lyrics.',
          ),
          const _InfoLine(
            icon: Icons.playlist_add_rounded,
            text: 'Use the playlist button beside a song to add it to an existing or new playlist; the heart saves a favorite.',
          ),
          const _InfoLine(
            icon: Icons.lyrics_outlined,
            text: 'Open Lyrics only for an immersive view. Paste plain or timed LRC lyrics in any script if none are found.',
          ),
          const _InfoLine(
            icon: Icons.settings_outlined,
            text: 'Settings controls appearance, accounts and library sync. This guide is available there later.',
          ),
        ] else ...[
          const _InfoLine(
            icon: Icons.person_outline,
            text: 'An account is optional. You can start with local music and connect cloud music later.',
          ),
          const _InfoLine(
            icon: Icons.security_outlined,
            text: 'Petal asks for access only when you choose a music source.',
          ),
          if (auth.error != null) ...[
            const SizedBox(height: 8),
            Text(
              auth.error!,
              style: TextStyle(color: Colors.redAccent.shade200),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: auth.loading
                ? null
                : () => _signIn(AuthProviderKind.google),
            icon: const Icon(Icons.g_mobiledata, size: 22),
            label: const Text('Connect Google Drive'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: auth.loading
                ? null
                : () => _signIn(AuthProviderKind.microsoft),
            icon: const Icon(Icons.window, size: 18),
            label: const Text('Connect OneDrive'),
          ),
          if (auth.loading) const LinearProgressIndicator(),
          TextButton(
            onPressed: auth.loading ? null : _useLocalOnly,
            child: Text(
              kIsWeb
                  ? 'Explore Petal without connecting'
                  : 'Continue without an account',
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: petal.colors.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: petal.text.heroSub)),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final bool granted;
  final bool denied;
  final bool busy;
  final VoidCallback onRequest;

  const _PermissionCard({
    required this.granted,
    required this.denied,
    required this.busy,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: petal.colors.surface2,
        borderRadius: BorderRadius.circular(PetalTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.audiotrack, size: 18, color: petal.colors.ink2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Access to your audio files',
                  style: petal.text.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Lets Petal find and play music stored on this phone. You can still pick individual files "
            "without this — it just makes importing faster.",
            style: petal.text.cardSubtitle,
          ),
          const SizedBox(height: 12),
          if (granted)
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: petal.colors.good),
                const SizedBox(width: 6),
                Text('Access granted', style: petal.text.cardSubtitle),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : onRequest,
                child: busy
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(denied ? 'Try again' : 'Allow access'),
              ),
            ),
        ],
      ),
    );
  }
}
