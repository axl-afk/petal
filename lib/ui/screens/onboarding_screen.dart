import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/auth_session.dart';
import '../../state/auth_controller.dart';
import '../../state/onboarding_controller.dart';
import '../../theme/app_theme.dart';

/// First-run screen: "sign in, or just play music already on this device"
/// (the product's own framing), plus — on Android — the explicit
/// "Petal would like access to your audio files" permission moment.
///
/// Why a real permission_handler request even though file_picker itself
/// doesn't need one: verified against file_picker's own manifest/changelog
/// that its Android (Storage Access Framework) and iOS (system document
/// picker) flows both work with zero runtime permission grants — so this
/// button is deliberately NOT gating anything Petal does today. It exists
/// because (a) the product wants an explicit, honest "this app will ask for
/// access" moment on first launch rather than silence, and (b) it's real,
/// working plumbing for a future on-device library scan (the Android
/// equivalent of "Scan whole computer" — see LibraryController's doc
/// comment on why that isn't implemented yet). Declining it doesn't block
/// anything: every import path today goes through the OS's own file/folder
/// picker, which works regardless. iOS gets no equivalent button — verified
/// there's no runtime permission dialog for iOS's document picker at all,
/// so a fake "allow access" button there would just be theater; the iOS
/// copy says so plainly instead.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _requestingPermission = false;
  PermissionStatus? _permissionResult;

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
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
    final audio = await Permission.audio.request();
    var result = audio;
    if (!audio.isGranted) {
      result = await Permission.storage.request();
    }
    if (!mounted) return;
    setState(() {
      _requestingPermission = false;
      _permissionResult = result;
    });
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
      backgroundColor: petal.colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/icon/icon_square.png', width: 72, height: 72),
                  ),
                  const SizedBox(height: 20),
                  Text('Welcome to Petal', style: petal.text.heroTitle.copyWith(fontSize: 26), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to bring your saved Drive/OneDrive links and playlists back on every '
                    'device, or skip straight to playing music already on this device.',
                    style: petal.text.heroSub,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  if (auth.error != null) ...[
                    Text(auth.error!, style: TextStyle(color: Colors.redAccent.shade200, fontSize: 12.5), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: auth.loading ? null : () => _signIn(AuthProviderKind.google),
                          icon: const Icon(Icons.g_mobiledata, size: 22),
                          label: const Text('Sign in with Google'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: auth.loading ? null : () => _signIn(AuthProviderKind.microsoft),
                          icon: const Icon(Icons.window, size: 18),
                          label: const Text('Sign in with Microsoft'),
                        ),
                      ),
                    ],
                  ),

                  if (auth.loading) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                  ],

                  const SizedBox(height: 18),

                  if (_isAndroid) ...[
                    _PermissionCard(
                      granted: _permissionResult?.isGranted ?? false,
                      denied: _permissionResult != null && !_permissionResult!.isGranted,
                      busy: _requestingPermission,
                      onRequest: _requestAudioAccess,
                    ),
                    const SizedBox(height: 18),
                  ] else if (_isIOS) ...[
                    Text(
                      "On iOS, Petal uses the Files app's own picker to import music — that needs no extra "
                      "permission from you, it just asks each time you choose a file.",
                      style: petal.text.cardSubtitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                  ],

                  TextButton(
                    onPressed: auth.loading ? null : _useLocalOnly,
                    child: const Text('Just play music on this device'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final bool granted;
  final bool denied;
  final bool busy;
  final VoidCallback onRequest;

  const _PermissionCard({required this.granted, required this.denied, required this.busy, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: petal.colors.surface2, borderRadius: BorderRadius.circular(PetalTheme.radiusCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.audiotrack, size: 18, color: petal.colors.ink2),
              const SizedBox(width: 8),
              Expanded(child: Text('Access to your audio files', style: petal.text.cardTitle)),
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
                    ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(denied ? 'Try again' : 'Allow access'),
              ),
            ),
        ],
      ),
    );
  }
}
