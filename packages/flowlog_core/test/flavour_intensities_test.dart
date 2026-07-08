import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('flavour intensities', () {
    test('normalize fills defaults for selected tags', () {
      final normalized = normalizeFlavourIntensities(
        selectedTags: {'chocolate', 'nutty'},
        intensities: {'chocolate': 8},
      );

      expect(normalized, {'chocolate': 8, 'nutty': 5});
    });

    test('round-trips through JSON encoding', () {
      const input = {'bright': 3, 'body': 9};
      final encoded = encodeFlavourIntensities(input);
      expect(decodeFlavourIntensities(encoded), input);
    });

    test('parses CSV summary format', () {
      final parsed = parseFlavourIntensitiesCsv('chocolate:7;nutty:5');
      expect(parsed, {'chocolate': 7, 'nutty': 5});
      expect(
        formatFlavourIntensitiesCsv(parsed),
        'chocolate:7;nutty:5',
      );
    });

    test('formats profile summary with fallback intensity', () {
      expect(
        formatFlavourProfileSummary(
          tags: ['chocolate', 'nutty'],
          intensities: {'chocolate': 7},
        ),
        'chocolate 7, nutty 5',
      );
    });
  });
}