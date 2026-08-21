// TrackArt (track_art.dart) needs to render a *local file path* as an
// image on desktop/mobile, but dart:io's File — the only way to do that —
// can't even be imported into code compiled for web (same constraint as
// data/services/local_file_service.dart; see that file's comment for the
// full explanation). Splitting just this one piece out lets TrackArt itself
// stay a normal, universal widget while this part swaps implementation per
// platform via conditional export.
export 'track_art_local_web.dart' if (dart.library.io) 'track_art_local_io.dart';
