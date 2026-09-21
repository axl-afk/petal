import 'dart:convert';

import 'package:charset/charset.dart';

/// Repairs the two common ways multilingual ID3 text is misread:
/// UTF-8 bytes declared as ID3 Latin-1, and UTF-8 bytes decoded as GBK.
///
/// A candidate is only accepted when it produces an Indic/Arabic script and
/// removes corruption markers. Legitimate Chinese/Japanese/Korean metadata is
/// therefore left untouched.
String cleanMetadataText(String value) {
  final input = value.replaceAll('\u0000', '').trim();
  if (input.isEmpty) return input;

  final candidates = <String>[input];

  if (input.codeUnits.every((unit) => unit <= 0xff)) {
    try {
      candidates.add(utf8.decode(latin1.encode(input)).trim());
    } catch (_) {
      // It was genuine Latin-1, not UTF-8 bytes stored in a Latin-1 frame.
    }
  }

  try {
    final bytes = gbk.encode(input);
    if (gbk.decode(bytes) == input) {
      candidates.add(utf8.decode(bytes).trim());
    }
  } catch (_) {
    // It was not reversible GBK mojibake.
  }

  var best = input;
  var bestScore = _score(input);
  for (final candidate in candidates.skip(1)) {
    final score = _score(candidate);
    if (score >= bestScore + 8) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
}

bool looksLikeCorruptedMetadata(String value) {
  if (value.contains('\uFFFD') || value.contains('Ã') || value.contains('Â')) {
    return true;
  }
  final repaired = cleanMetadataText(value);
  return repaired != value;
}

int _score(String value) {
  var score = 0;
  for (final rune in value.runes) {
    if (rune == 0xfffd || rune == 0x25a1) score -= 18;
    if (rune >= 0x80 && rune <= 0x9f) score -= 8;
    if (_isSupportedMusicScript(rune)) score += 4;
  }
  for (final marker in const ['Ã', 'Â', 'à¤', 'à¥', 'à¦', 'à§']) {
    if (value.contains(marker)) score -= 12;
  }
  return score;
}

bool _isSupportedMusicScript(int rune) =>
    (rune >= 0x0600 && rune <= 0x06ff) || // Arabic
    (rune >= 0x0900 && rune <= 0x097f) || // Devanagari / Hindi
    (rune >= 0x0980 && rune <= 0x09ff) || // Bengali
    (rune >= 0x0a00 && rune <= 0x0d7f) || // remaining Indic blocks
    (rune >= 0x0e00 && rune <= 0x0e7f) || // Thai
    (rune >= 0x0590 && rune <= 0x05ff); // Hebrew
