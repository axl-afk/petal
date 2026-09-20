// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:petal/utils/duration_format.dart';

void main() {
  test('formats track duration for the player UI', () {
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(minutes: 4, seconds: 9)), '4:09');
  });
}
