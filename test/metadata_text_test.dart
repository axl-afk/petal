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

  test('removes null padding used by legacy ID3 fields', () {
    expect(cleanMetadataText('Wishes\u0000\u0000'), 'Wishes');
  });
}
