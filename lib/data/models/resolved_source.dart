enum LinkProviderKind { googleDrive, oneDrive, direct, unknown }

/// The outcome of turning a pasted share link into something `just_audio`
/// can actually stream from.
class ResolvedSource {
  final bool ok;
  final LinkProviderKind provider;
  final String? playableUri;
  final String? suggestedTitle;
  final String? error;

  /// Set only for a Drive *folder* link (see LibraryController.connectLink)
  /// — how many audio files were found/actually imported, since a folder
  /// expands to many tracks rather than the one [playableUri] a normal
  /// link resolves to.
  final int? folderFound;
  final int? folderImported;

  const ResolvedSource._({
    required this.ok,
    required this.provider,
    this.playableUri,
    this.suggestedTitle,
    this.error,
    this.folderFound,
    this.folderImported,
  });

  factory ResolvedSource.success({
    required LinkProviderKind provider,
    required String playableUri,
    String? suggestedTitle,
  }) =>
      ResolvedSource._(
        ok: true,
        provider: provider,
        playableUri: playableUri,
        suggestedTitle: suggestedTitle,
      );

  factory ResolvedSource.folderSuccess({
    required LinkProviderKind provider,
    required int found,
    required int imported,
  }) =>
      ResolvedSource._(ok: true, provider: provider, folderFound: found, folderImported: imported);

  factory ResolvedSource.failure(String error, {LinkProviderKind provider = LinkProviderKind.unknown}) =>
      ResolvedSource._(ok: false, provider: provider, error: error);

  bool get isFolderResult => folderFound != null;
}
