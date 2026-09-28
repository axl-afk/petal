import 'package:flutter_test/flutter_test.dart';
import 'package:petal/data/services/local_file_service_io.dart';

void main() {
  test('untagged filenames retain script, case and punctuation', () {
    final files = LocalFileService();
    expect(files.titleFromFileName('أغنية_جديدة.mp3'), 'أغنية جديدة');
    expect(files.titleFromFileName('君の声-星.flac'), '君の声-星');
    expect(files.titleFromFileName('মনের_মানুষ.m4a'), 'মনের মানুষ');
    expect(files.titleFromFileName('iPhone-Été.mp3'), 'iPhone-Été');
  });
}
