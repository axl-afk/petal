import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Petal is a single-window app with a small, fixed set of sections — this
/// mirrors the approved HTML prototype's SPA-style `data-nav` switching
/// rather than pushing Navigator routes, which keeps the responsive
/// rail/top-bar/mini-player shell trivially in sync with "what's showing"
/// on every platform including web.
enum AppSection { library, nowPlaying, lyrics, addSource, settings }

final currentSectionProvider = StateProvider<AppSection>((ref) => AppSection.library);
