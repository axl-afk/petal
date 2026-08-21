import 'dart:io';

import 'package:flutter/widgets.dart';

/// Renders a local file path as artwork, falling back to [placeholder] if
/// the file is missing/unreadable (e.g. artwork whose file got cleaned up).
Widget buildLocalTrackArt({
  required String path,
  required double size,
  required BorderRadius radius,
  required Widget Function() placeholder,
}) {
  return ClipRRect(
    borderRadius: radius,
    child: Image.file(
      File(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder(),
    ),
  );
}
