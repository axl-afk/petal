enum LinkProviderKind { googleDrive, oneDrive, direct, unknown }

/// The outcome of turning a pasted share link into something `just_audio`
/// can actually stream from.
class ResolvedSource {
  final bool ok;
  final LinkProviderKind provider;
  final String? playableUri;
  final String? suggestedTitle;
  final String? error;

  const ResolvedSource._({
    required this.ok,
    required this.provider,
    this.playableUri,
    this.suggestedTitle,
    this.error,
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

  factory ResolvedSource.failure(String error, {LinkProviderKind provider = LinkProviderKind.unknown}) =>
      ResolvedSource._(ok: false, provider: provider, error: error);
}
