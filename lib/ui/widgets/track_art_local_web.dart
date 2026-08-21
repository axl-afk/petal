import 'package:flutter/widgets.dart';

/// Web stub — a local file path never resolves to anything in a browser
/// (LocalFileService's web stub never produces one either), so this just
/// always falls back to the placeholder.
Widget buildLocalTrackArt({
  required String path,
  required double size,
  required BorderRadius radius,
  required Widget Function() placeholder,
}) {
  return placeholder();
}
