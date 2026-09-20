import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/resolved_source.dart';
import '../../state/auth_controller.dart';
import '../../state/library_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/glass_surface.dart';

class AddSourceScreen extends ConsumerStatefulWidget {
  const AddSourceScreen({super.key});

  @override
  ConsumerState<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends ConsumerState<AddSourceScreen> {
  final _linkController = TextEditingController();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  bool _busy = false;
  bool _busyLocal = false;
  String? _error;
  String? _success;
  String? _localError;
  String? _localSuccess;
  int? _wholeComputerProgress;

  @override
  void dispose() {
    _linkController.dispose();
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    final email = ref.read(authControllerProvider).session?.email;
    // Pass the title through as-typed — including blank — rather than
    // pre-filling "Untitled Track" here. LibraryController.connectLink now
    // does something smarter with a blank title for a single Google Drive
    // link (looks up the file's real name via the Drive API when signed
    // in — see its doc comment); pre-filling the fallback here would have
    // defeated that before it ever got a chance to run. connectLink still
    // falls back to "Untitled Track" itself when the lookup isn't
    // possible/fails, so behavior is unchanged for every other case.
    final result = await ref
        .read(libraryControllerProvider.notifier)
        .connectLink(
          rawLink: _linkController.text,
          title: _titleController.text,
          artist: _artistController.text.isEmpty
              ? 'Unknown Artist'
              : _artistController.text,
          accountEmail: email,
        );

    setState(() {
      _busy = false;
      if (result.ok) {
        _success = result.isFolderResult
            ? _folderResultMessage(result)
            : 'Added — check Songs in your Library.';
        _linkController.clear();
        _titleController.clear();
        _artistController.clear();
      } else {
        _error = result.error ?? 'Something went wrong resolving that link.';
      }
    });
  }

  String _folderResultMessage(ResolvedSource result) {
    final found = result.folderFound!;
    final imported = result.folderImported!;
    if (imported == found) {
      return 'Imported $imported song${imported == 1 ? '' : 's'} from that folder — check Songs in your Library.';
    }
    return 'Imported $imported of $found songs from that folder — the rest couldn\'t be read.';
  }

  Future<void> _importLocal() async {
    setState(() {
      _busyLocal = true;
      _localError = null;
      _localSuccess = null;
    });
    try {
      final result = await ref
          .read(libraryControllerProvider.notifier)
          .importLocalFiles();
      setState(() => _localSuccess = _resultMessage(result));
    } catch (e) {
      setState(() => _localError = e.toString());
    } finally {
      setState(() => _busyLocal = false);
    }
  }

  Future<void> _importFolder() async {
    setState(() {
      _busyLocal = true;
      _localError = null;
      _localSuccess = null;
    });
    try {
      final result = await ref
          .read(libraryControllerProvider.notifier)
          .importFolder();
      setState(
        () => _localSuccess = result == null ? null : _resultMessage(result),
      );
    } catch (e) {
      setState(() => _localError = e.toString());
    } finally {
      setState(() => _busyLocal = false);
    }
  }

  Future<void> _scanMusicFolder() async {
    setState(() {
      _busyLocal = true;
      _localError = null;
      _localSuccess = null;
    });
    try {
      final result = await ref
          .read(libraryControllerProvider.notifier)
          .scanPlatformMusicFolder();
      setState(() {
        _localSuccess = result == null ? null : _resultMessage(result);
        _localError = result == null
            ? 'Couldn\'t find a Music folder on this machine — try "Choose a folder" instead.'
            : null;
      });
    } catch (e) {
      setState(() => _localError = e.toString());
    } finally {
      setState(() => _busyLocal = false);
    }
  }

  Future<void> _scanWholeComputer() async {
    setState(() {
      _busyLocal = true;
      _localError = null;
      _localSuccess = null;
      _wholeComputerProgress = 0;
    });
    try {
      final result = await ref
          .read(libraryControllerProvider.notifier)
          .scanWholeComputer(
            // Called from inside the scan, potentially many times a
            // second on a fast disk — setState is cheap enough here since
            // it's just updating one integer Text, not rebuilding the
            // track list.
            onProgress: (foundSoFar) {
              if (mounted) setState(() => _wholeComputerProgress = foundSoFar);
            },
          );
      setState(
        () => _localSuccess = result == null ? null : _resultMessage(result),
      );
    } catch (e) {
      setState(() => _localError = e.toString());
    } finally {
      setState(() {
        _busyLocal = false;
        _wholeComputerProgress = null;
      });
    }
  }

  Future<void> _scanDeviceMusic() async {
    setState(() {
      _busyLocal = true;
      _localError = null;
      _localSuccess = null;
    });
    try {
      final result = await ref
          .read(libraryControllerProvider.notifier)
          .scanDeviceMusic();
      setState(
        () => _localSuccess = result == null ? null : _resultMessage(result),
      );
    } catch (e) {
      setState(() => _localError = e.toString());
    } finally {
      if (mounted) setState(() => _busyLocal = false);
    }
  }

  // defaultTargetPlatform (flutter/foundation.dart) rather than dart:io's
  // Platform — the latter can't even be imported into a file compiled for
  // web (see local_file_service.dart's conditional-export comment for the
  // same constraint), while this is web-safe and reports the host OS.
  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String _resultMessage(ImportResult result) {
    if (result.found == 0) return 'No audio files found there.';
    if (result.imported == result.found) {
      return 'Imported ${result.imported} track${result.imported == 1 ? '' : 's'} into your library.';
    }
    return 'Imported ${result.imported} of ${result.found} files — the rest couldn\'t be read.';
  }

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a source',
              style: petal.text.heroTitle.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 6),
            Text(
              'Paste a single-song share link, a whole Google Drive folder link (needs Google '
              'sign-in — imports every song directly inside it), or import files from this device.',
              style: petal.text.heroSub,
            ),
            const SizedBox(height: 24),

            _Card(
              title: 'From a link',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(
                    controller: _linkController,
                    hint: 'A song link, a Drive folder link (drive.google.com/drive/folders/...), or a OneDrive link',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          controller: _titleController,
                          hint: 'Title (optional)',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Field(
                          controller: _artistController,
                          hint: 'Artist (optional)',
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Leave title blank for a single Google Drive file and, if you\'re signed in, '
                      'Petal fills it in from the file\'s real name automatically.',
                      style: petal.text.cardSubtitle,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: petal.colors.accent,
                        foregroundColor: petal.colors.accentInk,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PetalTheme.radiusPill,
                          ),
                        ),
                      ),
                      onPressed: _busy ? null : _connect,
                      child: _busy
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: petal.colors.accentInk,
                              ),
                            )
                          : const Text('Connect'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.redAccent.shade200,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _success!,
                      style: TextStyle(
                        color: petal.colors.good,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            _Card(
              title: 'From this device',
              child: kIsWeb
                  ? Text(
                      'The web version of Petal doesn\'t have access to local files — install the app for macOS, Windows, Linux, Android, or iOS to import from your device.',
                      style: petal.text.cardSubtitle,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import audio files already on this device.',
                          style: petal.text.cardSubtitle,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (_isAndroid)
                              FilledButton.icon(
                                onPressed: _busyLocal ? null : _scanDeviceMusic,
                                icon: const Icon(
                                  Icons.library_music_outlined,
                                  size: 18,
                                ),
                                label: const Text('Find device music'),
                              ),
                            OutlinedButton.icon(
                              onPressed: _busyLocal ? null : _importLocal,
                              icon: const Icon(
                                Icons.insert_drive_file_outlined,
                                size: 18,
                              ),
                              label: const Text('Choose files'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busyLocal ? null : _importFolder,
                              icon: const Icon(
                                Icons.folder_open_outlined,
                                size: 18,
                              ),
                              label: const Text('Choose a folder'),
                            ),
                            if (_isDesktop)
                              OutlinedButton.icon(
                                onPressed: _busyLocal ? null : _scanMusicFolder,
                                icon: const Icon(
                                  Icons.travel_explore_outlined,
                                  size: 18,
                                ),
                                label: const Text('Scan Music folder'),
                              ),
                            if (_isDesktop)
                              OutlinedButton.icon(
                                onPressed: _busyLocal
                                    ? null
                                    : _scanWholeComputer,
                                icon: const Icon(Icons.dns_outlined, size: 18),
                                label: const Text('Scan whole computer'),
                              ),
                          ],
                        ),
                        if (_busyLocal) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: petal.colors.ink2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _wholeComputerProgress != null
                                    ? 'Scanning your computer… $_wholeComputerProgress song${_wholeComputerProgress == 1 ? '' : 's'} found so far'
                                    : 'Scanning and importing…',
                                style: petal.text.meta,
                              ),
                            ],
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            '"Choose a folder" imports everything found in it, including subfolders. "Scan Music folder" '
                            'does the same for this machine\'s own Music folder — a quick way to pull in your whole '
                            'existing library without navigating to it by hand. "Scan whole computer" checks every '
                            'drive this machine can see, not just the Music folder — slower, but thorough if your '
                            'music lives somewhere else. On Android, “Find device music” reads the system MediaStore. '
                            'On iPhone and iPad, Apple does not expose a whole-device file scan, so use “Choose files” '
                            'and the native document picker.',
                            style: petal.text.cardSubtitle,
                          ),
                        ),
                        if (_localError != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _localError!,
                            style: TextStyle(
                              color: Colors.redAccent.shade200,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        if (_localSuccess != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _localSuccess!,
                            style: TextStyle(
                              color: petal.colors.good,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return GlassSurface(
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: petal.text.settingsGroupTitle),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _Field({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    final petal = context.petal;
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 13.5, color: petal.colors.ink),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(color: petal.colors.ink3, fontSize: 13),
        filled: true,
        fillColor: petal.colors.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
