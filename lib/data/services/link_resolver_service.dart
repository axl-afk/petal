import '../models/resolved_source.dart';

/// Turns a pasted Google Drive / OneDrive / generic share link into a direct
/// URL that `just_audio` can actually stream from — no OAuth required, which
/// is why v1 sign-in never needs Drive/OneDrive API scopes: this is a pure
/// URL-rewrite resolver against links the file's owner has already made
/// link-shareable.
class LinkResolverService {
  static final _driveFileId = RegExp(r'/file/d/([a-zA-Z0-9_-]+)');
  static final _driveIdParam = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
  static final _driveOpenPath = RegExp(r'drive\.google\.com/open');
  static final _driveFolderId = RegExp(r'drive\.google\.com/drive/(?:u/\d+/)?folders/([a-zA-Z0-9_-]+)');

  /// Returns the folder id if [rawInput] is a Google Drive *folder* share
  /// link, or null otherwise. Checked before [resolve] in
  /// LibraryController.connectLink — a folder doesn't resolve to one
  /// playable URL the way a single file does; listing what's inside it
  /// needs an actual Drive API call (see drive_folder_service.dart), which
  /// is why folder import specifically requires being signed in with
  /// Google, unlike a single-file link.
  String? driveFolderId(String rawInput) => _driveFolderId.firstMatch(rawInput.trim())?.group(1);

  ResolvedSource resolve(String rawInput) {
    final input = rawInput.trim();
    if (input.isEmpty) {
      return ResolvedSource.failure('Paste a share link first.');
    }

    final uri = Uri.tryParse(input);
    if (uri == null || !uri.hasScheme) {
      return ResolvedSource.failure("That doesn't look like a valid link.");
    }
    // Security review finding: only http(s) links should ever reach the
    // player. Without this, a pasted or synced (via Drive backup) value
    // using a local scheme (file://, content://, etc.) would fall through
    // to the generic "direct" branch below and get handed straight to
    // just_audio — an unintended local-resource-access path a link
    // resolver shouldn't have.
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return ResolvedSource.failure('Only http/https links are supported.');
    }

    final host = uri.host.toLowerCase();

    if (host.contains('drive.google.com') || host.contains('docs.google.com')) {
      return _resolveGoogleDrive(input, uri);
    }

    if (host.contains('onedrive.live.com') ||
        host.contains('1drv.ms') ||
        host.contains('sharepoint.com')) {
      return _resolveOneDrive(input, uri);
    }

    // Not a known cloud host — if it looks like it already points straight
    // at an audio file, let it through as-is.
    final path = uri.path.toLowerCase();
    const audioExt = ['.mp3', '.m4a', '.aac', '.wav', '.flac', '.ogg', '.opus'];
    if (audioExt.any(path.endsWith)) {
      return ResolvedSource.success(provider: LinkProviderKind.direct, playableUri: input);
    }

    return ResolvedSource.failure(
      "Couldn't recognize this link as a Google Drive, OneDrive, or direct audio-file link.",
      provider: LinkProviderKind.unknown,
    );
  }

  ResolvedSource _resolveGoogleDrive(String input, Uri uri) {
    String? id;
    final fileMatch = _driveFileId.firstMatch(input);
    if (fileMatch != null) id = fileMatch.group(1);
    id ??= _driveIdParam.firstMatch(input)?.group(1);

    if (id == null || id.isEmpty) {
      return ResolvedSource.failure(
        "Couldn't find a file ID in that Google Drive link. Make sure it's a "
        "single-file share link (Share > Copy link), not a folder.",
        provider: LinkProviderKind.googleDrive,
      );
    }

    final direct = 'https://drive.google.com/uc?export=download&id=$id';
    return ResolvedSource.success(provider: LinkProviderKind.googleDrive, playableUri: direct);
    // NOTE: very large files can trigger Drive's "can't scan this file for
    // viruses" interstitial, which requires following a `confirm=` token
    // instead of streaming directly. Not handled in v1 — see README known
    // limitations. Works reliably for typical audio file sizes.
  }

  ResolvedSource _resolveOneDrive(String input, Uri uri) {
    if (uri.host.contains('1drv.ms')) {
      // 1drv.ms short links redirect to the real onedrive.live.com URL; we
      // can't follow redirects here without an HTTP call, so hand the short
      // link straight to just_audio — most HTTP clients (including
      // just_audio's under the hood) follow redirects transparently anyway.
      return ResolvedSource.success(provider: LinkProviderKind.oneDrive, playableUri: input);
    }

    final hasQuery = uri.query.isNotEmpty;
    final separator = hasQuery ? '&' : '?';
    final alreadyHasDownload = uri.queryParameters.containsKey('download');
    final direct = alreadyHasDownload ? input : '$input${separator}download=1';

    return ResolvedSource.success(provider: LinkProviderKind.oneDrive, playableUri: direct);
  }
}
