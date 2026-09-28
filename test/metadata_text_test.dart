import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:petal/utils/metadata_text.dart';

void main() {
  test('repairs Hindi UTF-8 bytes misread as an ID3 Latin-1 frame', () {
    const original = 'तुम ही हो — अरिजीत सिंह';
    final mojibake = latin1.decode(utf8.encode(original));

    expect(cleanMetadataText(mojibake), original);
    expect(looksLikeCorruptedMetadata(mojibake), isTrue);
  });

  test('keeps legitimate Chinese metadata unchanged', () {
    const title = '月亮代表我的心';

    expect(cleanMetadataText(title), title);
    expect(looksLikeCorruptedMetadata(title), isFalse);
  });

  test('repairs Russian, Greek, Japanese and Korean UTF-8 tag mojibake', () {
    for (final original in ['Привет мир', 'Αγάπη', '夜に駆ける', '사랑해']) {
      final mojibake = latin1.decode(utf8.encode(original));
      expect(cleanMetadataText(mojibake), original);
    }
  });

  test('preserves correctly decoded multilingual metadata', () {
    for (final title in ['Москва', 'Αθήνα', '東京', '서울', 'ঢাকা', 'Édith Piaf']) {
      expect(cleanMetadataText(title), title);
    }
  });

  test('repairs accented Latin and emoji without harming original text', () {
    for (final original in ['Beyoncé', 'Été', 'Dance 🎵']) {
      expect(cleanMetadataText(latin1.decode(utf8.encode(original))), original);
      expect(cleanMetadataText(original), original);
    }
  });

  test('removes null padding used by legacy ID3 fields', () {
    expect(cleanMetadataText('Wishes\u0000\u0000'), 'Wishes');
  });
}
