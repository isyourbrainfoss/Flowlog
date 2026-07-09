import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('grind formatting', () {
    test('snapGrindSetting rounds to one decimal', () {
      expect(snapGrindSetting(3.599999999), 3.6);
      expect(snapGrindSetting(4.2000001), 4.2);
    });

    test('formatGrindSetting avoids floating-point noise', () {
      expect(formatGrindSetting(3.599999999), '3.6');
      expect(formatGrindSetting(14), '14.0');
      expect(formatGrindSetting(null), '—');
    });
  });
}