import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/auth_session.dart';
import '../../data/services/prefs_service.dart';
import '../../state/auth_controller.dart';
import '../../state/cloud_sync_controller.dart';
import '../../state/theme_controller.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petal = context.petal;
    final themeMode = ref.watch(themeControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final sync = ref.watch(cloudSyncControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: petal.text.heroTitle.copyWith(fontSize: 22)),
            const SizedBox(height: 20),

            _Group(
              title: 'APPEARANCE',
              child: Row(
                children: ThemeMode2.values.map((mode) {
                  final active = themeMode == mode;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_themeLabel(mode)),
                      selected: active,
                      onSelected: (_) => ref.read(themeControllerProvider.notifier).setMode(mode),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            _Group(
              title: 'ACCOUNT',
              child: auth.session == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign in so Petal remembers your Drive/OneDrive links and auto-connects them next time.',
                          style: petal.text.cardSubtitle,
                        ),
                        const SizedBox(height: 12),
                        if (auth.error != null) ...[
                          Text(auth.error!, style: TextStyle(color: Colors.redAccent.shade200, fontSize: 12.5)),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: auth.loading ? null : () => ref.read(authControllerProvider.notifier).signIn(AuthProviderKind.google),
                                icon: const Icon(Icons.g_mobiledata, size: 22),
                                label: const Text('Google'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    auth.loading ? null : () => ref.read(authControllerProvider.notifier).signIn(AuthProviderKind.microsoft),
                                icon: const Icon(Icons.window, size: 18),
                                label: const Text('Microsoft'),
                              ),
                            ),
                          ],
                        ),
                        if (auth.loading) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: petal.colors.surface2,
                              child: Text(auth.session!.email.substring(0, 1).toUpperCase(), style: TextStyle(color: petal.colors.ink)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(auth.session!.displayName ?? auth.session!.email, style: petal.text.cardTitle),
                                  Text(
                                    auth.session!.provider == AuthProviderKind.google ? 'Google Drive connected' : 'OneDrive connected',
                                    style: petal.text.cardSubtitle,
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                              child: const Text('Sign out'),
                            ),
                          ],
                        ),
                        if (auth.session!.provider == AuthProviderKind.google) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(
                                sync.status == CloudSyncStatus.error ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
                                size: 16,
                                color: sync.status == CloudSyncStatus.error ? Colors.redAccent.shade200 : petal.colors.ink3,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_syncStatusLabel(sync), style: petal.text.cardSubtitle),
                              ),
                              if (sync.status == CloudSyncStatus.syncing)
                                SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: petal.colors.ink3),
                                )
                              else
                                TextButton(
                                  onPressed: () => ref.read(cloudSyncControllerProvider.notifier).syncAfterSignIn(auth.session!.email),
                                  child: const Text('Sync now'),
                                ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Your saved Drive/OneDrive links, favorites, and playlists are backed up to a private, '
                              'hidden file in your own Google Drive — Petal doesn\'t run a server, and nothing here is '
                              'visible in your normal Drive. Locally-imported files stay on this device only.',
                              style: petal.text.cardSubtitle.copyWith(fontSize: 11.5),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          Text(
                            'Cross-device library backup is only available for Google accounts right now.',
                            style: petal.text.cardSubtitle.copyWith(fontSize: 11.5),
                          ),
                        ],
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            _Group(
              title: 'ABOUT',
              child: Text(
                'Petal — local files plus pasted Google Drive / OneDrive links, with time-synced lyrics from lrclib.net. '
                'Built with Flutter, drift (SQLite + FTS5), just_audio, and Riverpod.',
                style: petal.text.cardSubtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _syncStatusLabel(CloudSyncState sync) {
    if (sync.status == CloudSyncStatus.syncing) return 'Backing up to Google Drive…';
    if (sync.status == CloudSyncStatus.error) return 'Backup failed — see the error banner, or try again.';
    if (sync.lastSyncedAt != null) return 'Backed up to Google Drive';
    return 'Not backed up yet';
  }

  String _themeLabel(ThemeMode2 mode) => switch (mode) {
        ThemeMode2.light => 'Light',
        ThemeMode2.dark => 'Dark',
        ThemeMode2.auto => 'Auto',
      };
}

class _Group extends StatelessWidget {
  final String title;
  final Widget child;
  const _Group({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(color: petal.colors.surface, borderRadius: BorderRadius.circular(PetalTheme.radiusCard)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: petal.text.settingsGroupTitle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
